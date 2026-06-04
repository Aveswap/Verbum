#!/usr/bin/env python3
"""
Verbum — apply a curated deletion list to words_v2.db (prune the boring/over-common words).

Safety:
  - never deletes a curated gem (id in the GEMS_NAMESPACE set derived from word_batches_gems/)
  - never deletes a word whose row is referenced by the free-pool floor: after pruning, every
    (language, level) must keep >= FLOOR_HARD non-premium words (abort otherwise); warns < FLOOR_SOFT
  - matches by exact (language, lower(text)); for Ukrainian falls back to stress-insensitive match
    only when it is unambiguous; reports anything not found (changes nothing for those)

Input: a JSON file — array (or {"deletions": [...]}) of {language, text, reason?}.

Usage:
    python3 prune_words.py <deletions.json> --validate   # dry run: report, delete nothing
    python3 prune_words.py <deletions.json>              # delete + copy to Resources
"""
import argparse, json, os, sqlite3, sys, unicodedata, uuid, glob, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
DB = os.path.join(HERE, "words_v2.db")
RESOURCES_DB = os.path.join(HERE, "..", "Verbum", "Resources", "words_v2.db")
GEMS_NAMESPACE = uuid.UUID("a1b2c3d4-0000-4000-8000-000000000003")
PREMIUM = {"Technology", "Science", "Literature", "Society"}
FLOOR_HARD, FLOOR_SOFT = 50, 60


def norm(s):
    return "".join(c for c in unicodedata.normalize("NFD", s.lower()) if unicodedata.category(c) != "Mn")


def gem_ids():
    ids = set()
    for fp in glob.glob(os.path.join(HERE, "word_batches_gems", "*.json")):
        for e in json.load(open(fp, encoding="utf-8")):
            lang = {"English": "en", "German": "de", "Ukrainian": "uk"}.get(e.get("language"), e.get("language"))
            ids.add(str(uuid.uuid5(GEMS_NAMESPACE, f"{lang}:{e['text'].lower()}")))
    return ids


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("deletions")
    ap.add_argument("--validate", action="store_true")
    args = ap.parse_args()

    raw = json.load(open(args.deletions, encoding="utf-8"))
    items = raw.get("deletions") if isinstance(raw, dict) else raw

    con = sqlite3.connect(DB)
    con.row_factory = sqlite3.Row
    rows = con.execute("SELECT id, language, text, level, category FROM words").fetchall()
    by_exact, by_norm = {}, {}
    for r in rows:
        by_exact.setdefault((r["language"], r["text"].lower()), []).append(r)
        by_norm.setdefault((r["language"], norm(r["text"])), []).append(r)

    gems = gem_ids()
    to_delete, not_found, gem_skips = {}, [], []
    for it in items:
        lang, text = it.get("language"), (it.get("text") or "")
        matches = by_exact.get((lang, text.lower()))
        if not matches:
            nm = by_norm.get((lang, norm(text)))
            matches = nm if (nm and len(nm) == 1) else None
        if not matches:
            not_found.append(f"{lang}:{text}"); continue
        for m in matches:
            if m["id"] in gems:
                gem_skips.append(f"{lang}:{m['text']}"); continue
            to_delete[m["id"]] = m

    # Project per-(language, level) non-premium counts after deletion.
    del_ids = set(to_delete)
    counts = {}
    for r in rows:
        if r["category"] in PREMIUM:
            continue
        key = (r["language"], r["level"])
        counts.setdefault(key, [0, 0])
        counts[key][0] += 1
        if r["id"] not in del_ids:
            counts[key][1] += 1

    print(f"deletions requested: {len(items)} | matched rows: {len(to_delete)} | "
          f"not found: {len(not_found)} | gem-protected skips: {len(gem_skips)}")
    if not_found:
        print("  not found (left untouched):", ", ".join(not_found[:25]), ("…" if len(not_found) > 25 else ""))
    if gem_skips:
        print("  GEM-PROTECTED (NOT deleted):", ", ".join(gem_skips))

    violations, warnings = [], []
    print("\n  non-premium words per (language, level)  before → after  [floor %d]" % FLOOR_HARD)
    for key in sorted(counts):
        before, after = counts[key]
        flag = ""
        if after < FLOOR_HARD: violations.append((key, after)); flag = "  ✗ BELOW HARD FLOOR"
        elif after < FLOOR_SOFT: warnings.append((key, after)); flag = "  ⚠ below soft floor"
        print(f"    {key[0]}/{key[1]:<12} {before:4d} → {after:4d}{flag}")

    if violations:
        print("\nABORT: would drop these below the free-pool floor of %d:" % FLOOR_HARD, violations)
        sys.exit(1)
    if warnings:
        print("\n(soft-floor warnings only — proceeding is safe)")

    if args.validate:
        print("\n--validate: nothing written.")
        con.close(); return

    con.executemany("DELETE FROM words WHERE id = ?", [(i,) for i in del_ids])
    con.execute("INSERT INTO words_fts(words_fts) VALUES('rebuild')")
    con.commit()
    print(f"\nDeleted {len(del_ids)} rows.")
    for lang, n in con.execute("SELECT language, COUNT(*) FROM words GROUP BY language ORDER BY language"):
        print(f"  {lang}: {n} words")
    con.close()
    shutil.copyfile(DB, os.path.abspath(RESOURCES_DB))
    print(f"Copied → {os.path.abspath(RESOURCES_DB)}")
    print("Next: validate_content.py, then bump WordDatabase.bundledDBVersion.")


if __name__ == "__main__":
    main()
