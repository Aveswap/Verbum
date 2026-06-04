#!/usr/bin/env python3
"""
Verbum — drastic cull: keep ONLY the curated gem words (everything added via the deep-research
gem batches in word_batches_gems/), delete the rest of the catalogue.

This is the deliberate product pivot from a ~1000-word/language learner catalogue to a small,
hand-curated "gems only" set. Reversible from git history (Resources/words_v2.db is committed per
version). Run after the gems are imported; matches by (language, normalized text) so gem words that
were stored as original rows (import skipped them as duplicates, e.g. Sehnsucht) are also kept.

Usage:
    python3 keep_gems_only.py --validate   # report keep/delete counts, write nothing
    python3 keep_gems_only.py              # apply + copy to Resources
"""
import argparse, glob, json, os, sqlite3, unicodedata, shutil
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
DB = os.path.join(HERE, "words_v2.db")
RESOURCES_DB = os.path.join(HERE, "..", "Verbum", "Resources", "words_v2.db")
LANG = {"English": "en", "German": "de", "Ukrainian": "uk"}


def norm(s):
    return "".join(c for c in unicodedata.normalize("NFD", s.lower()) if unicodedata.category(c) != "Mn")


def gem_keys():
    keys = set()
    for fp in glob.glob(os.path.join(HERE, "word_batches_gems", "*.json")):
        for e in json.load(open(fp, encoding="utf-8")):
            keys.add((LANG.get(e.get("language"), e.get("language")), norm(e.get("text", ""))))
    return keys


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--validate", action="store_true")
    args = ap.parse_args()
    keys = gem_keys()
    con = sqlite3.connect(DB)
    con.row_factory = sqlite3.Row
    rows = con.execute("SELECT id, language, text FROM words").fetchall()
    delete = [r["id"] for r in rows if (r["language"], norm(r["text"])) not in keys]
    keep = len(rows) - len(delete)
    print(f"total {len(rows)} | keep {keep} | delete {len(delete)}")
    if args.validate:
        con.close(); return
    con.executemany("DELETE FROM words WHERE id = ?", [(i,) for i in delete])
    con.execute("INSERT INTO words_fts(words_fts) VALUES('rebuild')")
    con.commit()
    for lang, n in con.execute("SELECT language, COUNT(*) FROM words GROUP BY language ORDER BY language"):
        print(f"  {lang}: {n} words")
    con.close()
    shutil.copyfile(DB, os.path.abspath(RESOURCES_DB))
    print(f"Copied → {os.path.abspath(RESOURCES_DB)}")


if __name__ == "__main__":
    main()
