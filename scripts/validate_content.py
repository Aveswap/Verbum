#!/usr/bin/env python3
"""
Verbum — content validator for IPA phonetics and etymologies.

Etymologies and IPA are the two fields most prone to LLM hallucination / formatting
drift, so this script audits them in `scripts/words_v2.db` (or the raw batch JSONs).

Everything here is standard-library only (sqlite3, json, re, urllib) — no pip installs.
Offline structural checks always run; pass --online to additionally cross-reference the
free Wiktionary REST API (best-effort, rate-limited, network required).

Usage:
    python validate_content.py                  # validate words_v2.db (offline checks)
    python validate_content.py --batches        # validate scripts/word_batches/*.json instead
    python validate_content.py --ipa            # only IPA checks
    python validate_content.py --etymology      # only etymology checks
    python validate_content.py --online         # also cross-ref Wiktionary (slow)
    python validate_content.py --online --limit 50

Exit code is non-zero if any hard error is found (useful in CI).
"""
import argparse
import glob
import json
import os
import re
import sqlite3
import sys
import time
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(HERE, "words_v2.db")
BATCH_GLOB = os.path.join(HERE, "word_batches", "*.json")

# A pragmatic IPA character class: slashes wrap the transcription, and the body should be
# IPA letters / diacritics / stress + length marks — not ASCII spelling leaking through.
IPA_BODY = re.compile(
    r"^[a-zɑæɐəɛɜɪɨʊʌɔɒθðʃʒŋɡɹɾʁχʔʰʲˠˤbdfhjklmnprstvwzˈˌːˑ.̩̟̃͡ ()|-]+$",
    re.IGNORECASE,
)

PLACEHOLDER_ETY = {"", "origin unknown", "unknown", "n/a", "tbd", "—", "-"}


def load_from_db(path):
    if not os.path.exists(path):
        sys.exit(f"DB not found: {path}. Build it first (python import_batches.py).")
    con = sqlite3.connect(path)
    con.row_factory = sqlite3.Row
    rows = con.execute(
        "SELECT text, phonetic, etymology FROM words ORDER BY text"
    ).fetchall()
    con.close()
    return [dict(r) for r in rows]


def load_from_batches():
    words = []
    for fp in sorted(glob.glob(BATCH_GLOB)):
        with open(fp, encoding="utf-8") as f:
            words.extend(json.load(f))
    if not words:
        sys.exit(f"No batch words found under {BATCH_GLOB}")
    return words


def check_ipa(word):
    """Returns a list of (severity, message). severity in {'error','warn'}."""
    issues = []
    p = (word.get("phonetic") or "").strip()
    if not p:
        return [("warn", "missing phonetic")]
    if not (p.startswith("/") and p.endswith("/")) and not (
        p.startswith("[") and p.endswith("]")
    ):
        issues.append(("error", f"phonetic not slash/bracket-wrapped: {p!r}"))
    body = p.strip("/[]")
    if not body:
        issues.append(("error", "empty phonetic body"))
    elif not IPA_BODY.match(body):
        bad = [c for c in body if not IPA_BODY.match(c)]
        issues.append(("warn", f"suspicious IPA chars {set(bad)} in {p!r}"))
    return issues


def check_etymology(word):
    issues = []
    e = (word.get("etymology") or "").strip()
    if e.lower() in PLACEHOLDER_ETY:
        issues.append(("warn", "placeholder/empty etymology"))
        return issues
    if len(e) < 12:
        issues.append(("warn", f"suspiciously short etymology: {e!r}"))
    # A real etymology usually names an origin language or a coinage.
    origin_markers = (
        "latin", "greek", "english", "french", "german", "norse", "sanskrit",
        "italian", "spanish", "arabic", "dutch", "celtic", "hebrew", "portuguese",
        "russian", "japanese", "persian", "turkic", "frankish", "gothic", "slavic",
        "proto-", "coined", "from ", "derived", "akin to", "related to", "via ",
        "root", "stem", "prefix", "suffix", "century", "meaning",
    )
    if not any(m in e.lower() for m in origin_markers):
        issues.append(("warn", "etymology names no recognizable origin"))
    return issues


def wiktionary_extract(term):
    """Best-effort plain-text intro from Wiktionary REST. Returns '' on any failure."""
    url = (
        "https://en.wiktionary.org/api/rest_v1/page/summary/"
        + urllib.parse.quote(term)
    )
    req = urllib.request.Request(url, headers={"User-Agent": "Verbum-validator/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return (data.get("extract") or "").lower()
    except Exception:
        return ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--batches", action="store_true", help="validate word_batches/*.json")
    ap.add_argument("--ipa", action="store_true", help="only IPA checks")
    ap.add_argument("--etymology", action="store_true", help="only etymology checks")
    ap.add_argument("--online", action="store_true", help="cross-ref Wiktionary (slow)")
    ap.add_argument("--limit", type=int, default=0, help="cap words checked online")
    args = ap.parse_args()

    do_ipa = args.ipa or not args.etymology
    do_ety = args.etymology or not args.ipa

    words = load_from_batches() if args.batches else load_from_db(DB_PATH)
    print(f"Validating {len(words)} words ({'batches' if args.batches else 'db'})\n")

    errors = warns = 0
    online_checked = 0
    for w in words:
        msgs = []
        if do_ipa:
            msgs += check_ipa(w)
        if do_ety:
            msgs += check_etymology(w)
        for severity, msg in msgs:
            if severity == "error":
                errors += 1
            else:
                warns += 1
            print(f"  [{severity.upper()}] {w.get('text','?')}: {msg}")

        if args.online and do_ety and (args.limit == 0 or online_checked < args.limit):
            online_checked += 1
            extract = wiktionary_extract(w.get("text", ""))
            time.sleep(0.2)  # be polite to the API
            if extract:
                e = (w.get("etymology") or "").lower()
                shared = {t for t in re.findall(r"[a-z]{4,}", e) if t in extract}
                if not shared:
                    warns += 1
                    print(f"  [WARN] {w.get('text')}: etymology not corroborated by Wiktionary")

    print(f"\nDone. errors={errors} warnings={warns}", end="")
    if args.online:
        print(f" (online-checked {online_checked})", end="")
    print()
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
