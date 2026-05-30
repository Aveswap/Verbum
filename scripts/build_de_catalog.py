#!/usr/bin/env python3
"""
Verbum — build the German vocabulary catalogue from authored batches.

Unlike Ukrainian (derived from existing translations), German has no source data, so it is
authored as JSON batches in scripts/word_batches_de/*.json and imported here as language='de'
rows. Each entry references the parallel English concept by `en_id`; the script reuses that
English word's category / level / frequencyRank (and partOfSpeech unless overridden) so the
German catalogue stays concept-aligned and ordered the same way.

Entry shape (scripts/word_batches_de/*.json — a JSON array):
    {
      "en_id":       "<id of the parallel English word>",   // required
      "text":        "Sehnsucht",                            // required (native German word)
      "definition":  "tiefes, sehnsüchtiges Verlangen…",     // required (German)
      "example":     "Ihn überkam eine tiefe Sehnsucht.",    // optional (German)
      "phonetic":    "/ˈzeːnˌzʊxt/",                          // optional (IPA)
      "etymology":   "von 'sehnen' + 'Sucht'…",               // optional (German)
      "partOfSpeech":"Substantiv",                            // optional (else English value)
      "synonyms":    ["Verlangen"], "antonyms": [], "collocations": [],
      "register":    "neutral", "domainTags": []
    }

Idempotent: rebuilds all de rows from the batches. Writes scripts/words_v2.db and copies to
Verbum/Resources/words_v2.db. Bump WordDatabase.bundledDBVersion afterwards so the app re-seeds.

Usage:
    python build_de_catalog.py            # build + copy to Resources
    python build_de_catalog.py --validate # parse batches + check en_id links, don't write
    python build_de_catalog.py --stats
"""
import argparse
import glob
import json
import os
import shutil
import sqlite3
import sys
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
DB = os.path.join(HERE, "words_v2.db")
RESOURCES_DB = os.path.join(HERE, "..", "Verbum", "Resources", "words_v2.db")
BATCH_GLOB = os.path.join(HERE, "word_batches_de", "*.json")
DE_NAMESPACE = uuid.UUID("a1b2c3d4-0000-4000-8000-000000000002")


def has_language_column(con):
    return "language" in [r[1] for r in con.execute("PRAGMA table_info(words)")]


def load_batches():
    words = []
    for fp in sorted(glob.glob(BATCH_GLOB)):
        with open(fp, encoding="utf-8") as f:
            words.extend(json.load(f))
    return words


def jstr(v):
    return json.dumps(v or [], ensure_ascii=False)


def build(con, validate_only=False):
    if not has_language_column(con):
        if not validate_only:
            con.execute("ALTER TABLE words ADD COLUMN language TEXT NOT NULL DEFAULT 'en'")
            con.execute("CREATE INDEX IF NOT EXISTS words_language_idx ON words(language)")

    entries = load_batches()
    if not entries:
        sys.exit(f"No German batches under {BATCH_GLOB}")

    # Pull the parallel English rows we'll inherit metadata from.
    en = {}
    for row in con.execute(
        "SELECT id, partOfSpeech, category, level, frequencyRank FROM words WHERE language='en'"
    ):
        en[row[0].lower()] = row

    errors, prepared, seen_text = [], [], set()
    for i, e in enumerate(entries):
        en_id = (e.get("en_id") or "").lower()
        text = (e.get("text") or "").strip()
        definition = (e.get("definition") or "").strip()
        if not en_id or en_id not in en:
            errors.append(f"[{i}] missing/unknown en_id: {e.get('en_id')!r} (text={text!r})")
            continue
        if not text or not definition:
            errors.append(f"[{i}] missing text/definition for en_id {en_id}")
            continue
        if text.lower() in seen_text:
            errors.append(f"[{i}] duplicate German word: {text!r}")
            continue
        seen_text.add(text.lower())
        _, en_pos, category, level, freq = en[en_id]
        prepared.append((
            str(uuid.uuid5(DE_NAMESPACE, f"{en_id}:de")),
            text, e.get("phonetic", "") or "",
            e.get("partOfSpeech") or en_pos or "",
            definition, e.get("example"),
            jstr(e.get("synonyms")), category, level, e.get("etymology"),
            freq, jstr(e.get("antonyms")), jstr(e.get("collocations")),
            e.get("register"), jstr(e.get("domainTags")),
        ))

    if errors:
        print("VALIDATION ERRORS:")
        for er in errors:
            print("  " + er)
    print(f"{len(prepared)} German entries ready, {len(errors)} errors")
    if validate_only or errors:
        return len(prepared) if not errors else -1

    con.execute("DELETE FROM words WHERE language='de'")
    con.executemany("""
        INSERT OR REPLACE INTO words
        (id, text, phonetic, partOfSpeech, definition, exampleSentence, synonyms,
         category, level, etymology, frequencyRank, antonyms, collocations,
         register, domainTags, language)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,'de')
    """, prepared)
    con.execute("INSERT OR IGNORE INTO grdb_migrations(identifier) VALUES('v3_language')")
    con.execute("INSERT INTO words_fts(words_fts) VALUES('rebuild')")
    con.commit()
    return len(prepared)


def stats(con):
    if not has_language_column(con):
        print("  (no language column yet)")
        return
    for lang in [r[0] for r in con.execute("SELECT DISTINCT language FROM words ORDER BY language")]:
        n = con.execute("SELECT COUNT(*) FROM words WHERE language=?", (lang,)).fetchone()[0]
        print(f"  {lang}: {n} words")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--validate", action="store_true")
    ap.add_argument("--stats", action="store_true")
    args = ap.parse_args()

    con = sqlite3.connect(DB)
    if args.stats:
        stats(con); con.close(); return
    n = build(con, validate_only=args.validate)
    if args.validate:
        con.close()
        sys.exit(0 if n >= 0 else 1)
    print(f"Imported German catalogue: {n} words")
    stats(con)
    con.close()
    shutil.copyfile(DB, os.path.abspath(RESOURCES_DB))
    print(f"Copied → {os.path.abspath(RESOURCES_DB)}")
    print("Next: bump WordDatabase.bundledDBVersion so the app re-seeds.")


if __name__ == "__main__":
    main()
