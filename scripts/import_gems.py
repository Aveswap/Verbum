#!/usr/bin/env python3
"""
Verbum — import curated "wow-tier" gem words from deep-research JSON into words_v2.db.

Unlike the parallel catalogues (build_de/build_uk derive de/uk from the English concept by
`en_id`), gems are STANDALONE language-native words (Waldeinsamkeit, серпанок, petrichor) with no
English parallel. This script inserts them as independent rows, normalizing the loose
deep-research field format to the DB schema, and is idempotent (stable id per language+text).

IMPORTANT: run this LAST in the pipeline — build_de_catalog.py / build_uk_catalog.py do
`DELETE FROM words WHERE language=…` and would wipe gems if run afterwards.

Input: every *.json under scripts/word_batches_gems/ — a JSON array of objects using the
deep-research field names:
    text, phonetic, partOfSpeech, definition, exampleSentence, synonyms, category, level,
    etymology, register, language   (+ optional "freePool": true, "frequencyRank": <int>)

Normalization performed:
  - language  "English"/"German"/"Ukrainian"  → en/de/uk (also accepts en/de/uk)
  - partOfSpeech  any of noun/Substantiv/іменник/… → canonical noun|verb|adjective|adverb
  - synonyms  "a, b" or ["a","b"] → JSON array; drops "(none)"/parenthetical placeholders
  - phonetic  keeps the first /…/ or […]; strips trailing notes like "(non-rhotic …)";
              Ukrainian keeps whatever is given (blank by design; stress lives in `text`)
  - frequencyRank  uses the entry's value if present; else assigns within (language, level):
                   freePool→a low rank (enters the free 50), otherwise paid-depth (high rank)
  - skips a gem whose lowercased text already exists in that language (keeps lemmas distinct)

Usage:
    python3 import_gems.py            # import + copy to Resources
    python3 import_gems.py --validate # parse + normalize + report, don't write
    python3 import_gems.py --stats
"""
import argparse, glob, json, os, re, sqlite3, uuid

HERE = os.path.dirname(os.path.abspath(__file__))
DB = os.path.join(HERE, "words_v2.db")
RESOURCES_DB = os.path.join(HERE, "..", "Verbum", "Resources", "words_v2.db")
BATCH_GLOB = os.path.join(HERE, "word_batches_gems", "*.json")
GEMS_NAMESPACE = uuid.UUID("a1b2c3d4-0000-4000-8000-000000000003")

LANG = {"english": "en", "german": "de", "ukrainian": "uk", "en": "en", "de": "de", "uk": "uk"}
# Free-pool seeds get ranks below the existing 50th word; paid-depth gems sit high so they
# don't disturb the free pool. (Existing catalogue ranks run into the thousands.)
FREE_BASE, PAID_BASE = 1, 9000


def pos_canonical(raw: str) -> str:
    s = (raw or "").lower()
    if any(k in s for k in ("verb", "дієслово")):       return "verb"
    if any(k in s for k in ("adverb", "прислівник")):   return "adverb"
    if any(k in s for k in ("adjective", "adjektiv", "прикметник", "прикм")): return "adjective"
    if any(k in s for k in ("noun", "substantiv", "іменник")): return "noun"
    return "noun"  # safe default; most gems are nouns


def clean_phonetic(raw: str, lang: str) -> str:
    p = (raw or "").strip()
    if not p:
        return ""
    if lang == "uk":          # design: uk carries stress in `text`, phonetic stays blank
        return ""
    m = re.search(r"(/[^/]+/|\[[^\]]+\])", p)   # first slash- or bracket-wrapped transcription
    return m.group(1) if m else p


def syn_list(raw):
    if isinstance(raw, list):
        items = raw
    else:
        items = re.split(r"[;,]", raw or "")
    out = []
    for s in items:
        s = s.strip()
        if not s or s.startswith("(") or s.lower() in ("none", "немає", "keine"):
            continue
        out.append(s)
    return out


def load_entries():
    entries = []
    for fp in sorted(glob.glob(BATCH_GLOB)):
        with open(fp, encoding="utf-8") as f:
            entries.extend(json.load(f))
    return entries


def existing_lemmas(con):
    # lang -> {lowercased text: id}; lets us skip collisions with REAL catalogue words while
    # still allowing a gem to update its own previously-imported row (same stable id).
    rows = con.execute("SELECT language, lower(text), id FROM words").fetchall()
    by_lang = {}
    for lang, t, _id in rows:
        by_lang.setdefault(lang, {})[t] = _id
    return by_lang


def normalize(entries, con):
    existing = existing_lemmas(con)
    counters = {}            # (lang, pool) -> running rank
    prepared, errors, skipped = [], [], []
    for i, e in enumerate(entries):
        lang = LANG.get(str(e.get("language", "")).strip().lower())
        text = (e.get("text") or "").strip()
        definition = (e.get("definition") or "").strip()
        if not lang:        errors.append(f"[{i}] unknown language {e.get('language')!r}"); continue
        if not text or not definition: errors.append(f"[{i}] missing text/definition ({text!r})"); continue
        gem_id = str(uuid.uuid5(GEMS_NAMESPACE, f"{lang}:{text.lower()}"))
        clash = existing.get(lang, {}).get(text.lower())
        if (clash and clash != gem_id) or text.lower() in {p['text'].lower() for p in prepared if p['language'] == lang}:
            skipped.append(f"{lang}:{text}"); continue   # collides with a real catalogue word

        if e.get("frequencyRank") is not None:
            rank = int(e["frequencyRank"])
        else:
            pool = "free" if e.get("freePool") else "paid"
            key = (lang, pool)
            counters[key] = counters.get(key, (FREE_BASE if pool == "free" else PAID_BASE)) + 1
            rank = counters[key]

        prepared.append({
            "id": gem_id,
            "text": text,
            "phonetic": clean_phonetic(e.get("phonetic"), lang),
            "partOfSpeech": pos_canonical(e.get("partOfSpeech")),
            "definition": definition,
            "exampleSentence": (e.get("exampleSentence") or "").strip() or None,
            "synonyms": json.dumps(syn_list(e.get("synonyms")), ensure_ascii=False),
            "category": (e.get("category") or "General").strip(),
            "etymology": (e.get("etymology") or "").strip() or None,
            "frequencyRank": rank,
            "register": (e.get("register") or "").strip() or None,
            "language": lang,
        })
    return prepared, errors, skipped


def write(con, prepared):
    for p in prepared:
        con.execute("""
            INSERT OR REPLACE INTO words
            (id, text, phonetic, partOfSpeech, definition, exampleSentence, synonyms,
             category, etymology, frequencyRank, antonyms, collocations,
             register, domainTags, language)
            VALUES (:id,:text,:phonetic,:partOfSpeech,:definition,:exampleSentence,:synonyms,
                    :category,:etymology,:frequencyRank,'[]','[]',:register,'[]',:language)
        """, p)
    con.execute("INSERT INTO words_fts(words_fts) VALUES('rebuild')")
    con.commit()


def stats(con):
    for lang, n in con.execute("SELECT language, COUNT(*) FROM words GROUP BY language ORDER BY language"):
        print(f"  {lang}: {n} words")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--validate", action="store_true")
    ap.add_argument("--stats", action="store_true")
    args = ap.parse_args()
    con = sqlite3.connect(DB)
    if args.stats:
        stats(con); con.close(); return
    entries = load_entries()
    if not entries:
        raise SystemExit(f"No gem files under {BATCH_GLOB} — drop the (clean UTF-8) research JSON there.")
    prepared, errors, skipped = normalize(entries, con)
    print(f"Parsed {len(entries)} gems → {len(prepared)} importable, {len(skipped)} duplicate-skipped, {len(errors)} errors")
    for s in errors: print("  ERROR", s)
    if skipped: print("  skipped (lemma already exists):", ", ".join(skipped))
    if errors:
        raise SystemExit("Fix errors before importing.")
    if args.validate:
        con.close(); return
    write(con, prepared)
    print(f"Imported {len(prepared)} gems.")
    stats(con)
    con.close()
    import shutil
    shutil.copyfile(DB, os.path.abspath(RESOURCES_DB))
    print(f"Copied → {os.path.abspath(RESOURCES_DB)}")
    print("Next: run validate_content.py, then bump WordDatabase.bundledDBVersion.")


if __name__ == "__main__":
    main()
