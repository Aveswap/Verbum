#!/usr/bin/env python3
"""
Verbum — derive a Ukrainian vocabulary catalogue from the existing uk translations.

The app now teaches words in ONE language at a time (parallel catalogues). The Ukrainian
catalogue is built from the `translations` (lang='uk') rows we already authored: each uk
translation is stored as "<ukrainian headword>; <ukrainian definition>", so we split it into
a real uk word + definition, reusing the parallel English word's partOfSpeech / category /
level / frequencyRank (same concept → same position when sorted by frequency).

Idempotent: re-running rebuilds the uk rows from scratch. Writes back to scripts/words_v2.db
and copies it to Verbum/Resources/words_v2.db. Bump WordDatabase.bundledDBVersion afterwards
so the app re-seeds.

Usage:
    python build_uk_catalog.py            # build + copy to Resources
    python build_uk_catalog.py --stats    # just print counts
"""
import argparse
import os
import shutil
import sqlite3
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
DB = os.path.join(HERE, "words_v2.db")
RESOURCES_DB = os.path.join(HERE, "..", "Verbum", "Resources", "words_v2.db")

UK_NAMESPACE = uuid.UUID("a1b2c3d4-0000-4000-8000-000000000001")  # stable derivation seed


def has_language_column(con):
    cols = [r[1] for r in con.execute("PRAGMA table_info(words)")]
    return "language" in cols


def split_uk(definition: str):
    """'<headword>; <definition>' → (headword, definition). No ';' → headword = whole."""
    if ";" in definition:
        head, _, rest = definition.partition(";")
        head, rest = head.strip(), rest.strip()
        return (head or definition.strip(), rest or definition.strip())
    d = definition.strip()
    return (d, d)


def build(con):
    if not has_language_column(con):
        con.execute("ALTER TABLE words ADD COLUMN language TEXT NOT NULL DEFAULT 'en'")
        con.execute("CREATE INDEX IF NOT EXISTS words_language_idx ON words(language)")
        con.execute("UPDATE words SET language='en' WHERE language IS NULL OR language=''")

    # Fresh uk catalogue every run.
    con.execute("DELETE FROM words WHERE language='uk'")

    rows = con.execute("""
        SELECT w.id, w.partOfSpeech, w.category, w.level, w.frequencyRank,
               t.definition, t.example
        FROM words w
        JOIN translations t ON t.word_id = w.id AND t.lang='uk'
        WHERE w.language='en'
    """).fetchall()

    inserted = 0
    for en_id, pos, category, level, freq, uk_def, uk_ex in rows:
        head, definition = split_uk(uk_def or "")
        if not head:
            continue
        # Stable id derived from the English word's id, so uk progress survives rebuilds.
        uk_id = str(uuid.uuid5(UK_NAMESPACE, f"{en_id.lower()}:uk"))
        con.execute("""
            INSERT OR REPLACE INTO words
            (id, text, phonetic, partOfSpeech, definition, exampleSentence, synonyms,
             category, level, etymology, frequencyRank, antonyms, collocations,
             register, domainTags, language)
            VALUES (?, ?, '', ?, ?, ?, '[]', ?, ?, NULL, ?, '[]', '[]', NULL, '[]', 'uk')
        """, (uk_id, head, pos or "", definition, uk_ex, category or "", level, freq))
        inserted += 1

    # Mark the Swift migration as applied so the in-app GRDB migrator doesn't try to
    # re-add the `language` column to this already-migrated bundle.
    con.execute("INSERT OR IGNORE INTO grdb_migrations(identifier) VALUES('v3_language')")

    # External-content FTS index must be rebuilt after row changes.
    con.execute("INSERT INTO words_fts(words_fts) VALUES('rebuild')")
    con.commit()
    return inserted


def stats(con):
    if not has_language_column(con):
        n = con.execute("SELECT COUNT(*) FROM words").fetchone()[0]
        print(f"  en: {n} words (no language column yet)")
        return
    langs = [r[0] for r in con.execute("SELECT DISTINCT language FROM words ORDER BY language")]
    for lang in langs:
        n = con.execute("SELECT COUNT(*) FROM words WHERE language=?", (lang,)).fetchone()[0]
        print(f"  {lang}: {n} words")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--stats", action="store_true")
    args = ap.parse_args()

    con = sqlite3.connect(DB)
    if args.stats:
        stats(con)
        con.close()
        return

    inserted = build(con)
    print(f"Built Ukrainian catalogue: {inserted} words")
    stats(con)
    con.close()

    shutil.copyfile(DB, os.path.abspath(RESOURCES_DB))
    print(f"Copied → {os.path.abspath(RESOURCES_DB)}")
    print("Next: bump WordDatabase.bundledDBVersion so the app re-seeds.")


if __name__ == "__main__":
    main()
