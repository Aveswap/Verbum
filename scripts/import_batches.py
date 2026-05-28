#!/usr/bin/env python3
"""
Verbum — import JSON batches into words_v2.db.

No API calls. Reads every `*.json` file inside `scripts/word_batches/`, validates
each word, deduplicates by text, and writes a fresh `scripts/words_v2.db` ready
to upload to the CDN.

The schema is identical to `generate_1000_words.py` — same DDL, same migration
metadata seeded, same FTS5 tokenizer — so the iOS app opens the resulting DB
the same way regardless of which producer made it.

Usage:
    python import_batches.py            # build words_v2.db
    python import_batches.py --validate # validate without writing
    python import_batches.py --stats    # show per-(category, level) counts

Batch file format — `scripts/word_batches/<anything>.json`:
    [
      {
        "id":              "uuid-v4",
        "text":            "serendipity",
        "phonetic":        "/ˌserənˈdɪpəti/",
        "partOfSpeech":    "noun",
        "definition":      "The occurrence of finding pleasant things by chance.",
        "exampleSentence": "Meeting her at the cafe was pure serendipity.",
        "synonyms":        ["chance", "fortuity"],
        "antonyms":        ["misfortune"],
        "collocations":    ["happy serendipity", "serendipity of life"],
        "category":        "General",
        "level":           "intermediate",
        "etymology":       "Coined by Horace Walpole in 1754 from the Persian tale 'The Three Princes of Serendip'.",
        "frequencyRank":   3200,
        "register":        "formal",
        "domainTags":      ["literary", "abstract"]
      },
      ...
    ]
"""

import argparse
import json
import re
import sqlite3
import sys
from collections import Counter
from pathlib import Path

BATCH_DIR = Path(__file__).parent / "word_batches"
DB_PATH   = Path(__file__).parent / "words_v2.db"

VALID_LEVELS = {"beginner", "intermediate", "expert"}
VALID_REGISTERS = {"formal", "informal", "neutral", "slang", "archaic"}
VALID_POS = {"noun", "verb", "adjective", "adverb", "phrase", "idiom"}
DB_CATEGORIES = {
    "Body", "Character", "Communication", "Emotions", "Food", "General",
    "Literature", "People", "Psychology", "Science", "Society", "Technology",
}

IPA_RE  = re.compile(r"^/.+/$")
UUID_RE = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")

DDL = """
CREATE TABLE IF NOT EXISTS words (
    id              TEXT PRIMARY KEY,
    text            TEXT NOT NULL,
    phonetic        TEXT NOT NULL DEFAULT '',
    partOfSpeech    TEXT NOT NULL DEFAULT '',
    definition      TEXT NOT NULL,
    exampleSentence TEXT,
    synonyms        TEXT NOT NULL DEFAULT '[]',
    category        TEXT NOT NULL DEFAULT '',
    level           TEXT NOT NULL,
    isBookmarked    INTEGER NOT NULL DEFAULT 0,
    isLiked         INTEGER NOT NULL DEFAULT 0,
    isNew           INTEGER NOT NULL DEFAULT 0,
    etymology       TEXT,
    antonyms        TEXT NOT NULL DEFAULT '[]',
    collocations    TEXT NOT NULL DEFAULT '[]',
    register        TEXT,
    domainTags      TEXT NOT NULL DEFAULT '[]',
    frequencyRank   INTEGER
);

CREATE TABLE IF NOT EXISTS translations (
    word_id    TEXT NOT NULL REFERENCES words(id) ON DELETE CASCADE,
    lang       TEXT NOT NULL,
    definition TEXT NOT NULL,
    example    TEXT,
    PRIMARY KEY (word_id, lang)
);

CREATE VIRTUAL TABLE IF NOT EXISTS words_fts USING fts5(
    text, definition, category,
    content=words, content_rowid=rowid,
    tokenize='unicode61 remove_diacritics 2'
);

CREATE INDEX IF NOT EXISTS idx_words_category ON words(category);
CREATE INDEX IF NOT EXISTS idx_words_level    ON words(level);

-- Pre-seed GRDB migration metadata so the iOS app's WordDatabase doesn't try
-- to re-run v2_enrichment on a DB that already has all v2 columns.
-- See WORDS_DB_PIPELINE.md ⚠️ Critical schema gotcha for context.
CREATE TABLE IF NOT EXISTS grdb_migrations (identifier TEXT NOT NULL PRIMARY KEY);
INSERT OR IGNORE INTO grdb_migrations(identifier) VALUES ('v1_createWords');
INSERT OR IGNORE INTO grdb_migrations(identifier) VALUES ('v2_enrichment');
"""

# --------- Validation ------------------------------------------------------

def validate_word(w: dict, source: str) -> list[str]:
    errors = []
    required = ["id", "text", "phonetic", "partOfSpeech", "definition",
                "synonyms", "antonyms", "collocations", "category", "level"]
    for key in required:
        if key not in w:
            errors.append(f"{source}: word missing field '{key}': {w.get('text', '?')}")
    if "id" in w and not UUID_RE.match(str(w["id"]).lower()):
        errors.append(f"{source}: bad uuid for '{w.get('text')}': {w['id']}")
    if "phonetic" in w and not IPA_RE.match(str(w["phonetic"])):
        errors.append(f"{source}: bad phonetic for '{w.get('text')}': {w['phonetic']}")
    if "partOfSpeech" in w and w["partOfSpeech"] not in VALID_POS:
        errors.append(f"{source}: bad partOfSpeech for '{w.get('text')}': {w['partOfSpeech']}")
    if "level" in w and w["level"] not in VALID_LEVELS:
        errors.append(f"{source}: bad level for '{w.get('text')}': {w['level']}")
    if "category" in w and w["category"] not in DB_CATEGORIES:
        errors.append(f"{source}: bad category for '{w.get('text')}': {w['category']}")
    if "register" in w and w["register"] is not None and w["register"] not in VALID_REGISTERS:
        errors.append(f"{source}: bad register for '{w.get('text')}': {w['register']}")
    for arr_key in ["synonyms", "antonyms", "collocations", "domainTags"]:
        v = w.get(arr_key, [])
        if not isinstance(v, list):
            errors.append(f"{source}: '{arr_key}' not a list for '{w.get('text')}'")
    return errors

# --------- Collection ------------------------------------------------------

def collect_batches() -> tuple[list[dict], list[str]]:
    if not BATCH_DIR.exists():
        return [], [f"Batch directory does not exist: {BATCH_DIR}"]
    files = sorted(BATCH_DIR.glob("*.json"))
    if not files:
        return [], [f"No JSON batches found in {BATCH_DIR}"]

    all_words: list[dict] = []
    errors: list[str] = []
    seen_texts: dict[str, str] = {}   # text -> source batch
    seen_ids: dict[str, str]   = {}   # id   -> source batch

    for f in files:
        source = f.name
        try:
            data = json.loads(f.read_text())
        except json.JSONDecodeError as e:
            errors.append(f"{source}: invalid JSON — {e}")
            continue
        if not isinstance(data, list):
            errors.append(f"{source}: top-level JSON must be a list")
            continue
        for w in data:
            if not isinstance(w, dict):
                errors.append(f"{source}: non-object in array")
                continue
            errs = validate_word(w, source)
            if errs:
                errors.extend(errs)
                continue
            text_key = w["text"].strip().lower()
            id_key = str(w["id"]).lower()
            if text_key in seen_texts:
                errors.append(f"{source}: duplicate text '{w['text']}' (also in {seen_texts[text_key]})")
                continue
            if id_key in seen_ids:
                errors.append(f"{source}: duplicate id '{id_key}' (also in {seen_ids[id_key]})")
                continue
            seen_texts[text_key] = source
            seen_ids[id_key] = source
            all_words.append(w)
    return all_words, errors

# --------- Stats -----------------------------------------------------------

def print_stats(words: list[dict]):
    print(f"\nTotal words: {len(words)}")
    by_level = Counter(w["level"] for w in words)
    print(f"By level:")
    for lvl in ["beginner", "intermediate", "expert"]:
        print(f"  {lvl:>13}: {by_level.get(lvl, 0)}")
    print(f"By category:")
    by_cat = Counter(w["category"] for w in words)
    for cat in sorted(DB_CATEGORIES):
        b = sum(1 for w in words if w["category"] == cat and w["level"] == "beginner")
        i = sum(1 for w in words if w["category"] == cat and w["level"] == "intermediate")
        e = sum(1 for w in words if w["category"] == cat and w["level"] == "expert")
        marker = " [premium]" if cat in {"Technology", "Science", "Literature", "Society"} else ""
        print(f"  {cat:>13}{marker:<10}  B:{b:3d}  I:{i:3d}  E:{e:3d}")
    # Free-pool feasibility check
    premium = {"Technology", "Science", "Literature", "Society"}
    print(f"\nFree-pool feasibility (need ≥50 non-premium per level):")
    for lvl in ["beginner", "intermediate", "expert"]:
        n = sum(1 for w in words if w["level"] == lvl and w["category"] not in premium)
        marker = "✓" if n >= 50 else f"✗ short by {50 - n}"
        print(f"  {lvl:>13}: {n:>3d} non-premium  {marker}")

# --------- Build -----------------------------------------------------------

def build_db(words: list[dict]):
    if DB_PATH.exists():
        DB_PATH.unlink()
    con = sqlite3.connect(DB_PATH)
    con.execute("PRAGMA journal_mode=WAL")
    con.executescript(DDL)
    with con:
        for w in words:
            con.execute("""
                INSERT INTO words
                (id, text, phonetic, partOfSpeech, definition, exampleSentence,
                 synonyms, category, level, etymology,
                 antonyms, collocations, register, domainTags, frequencyRank)
                VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
            """, (
                str(w["id"]).lower(),
                w["text"],
                w["phonetic"],
                w["partOfSpeech"],
                w["definition"],
                w.get("exampleSentence"),
                json.dumps(w.get("synonyms", []), ensure_ascii=False),
                w["category"],
                w["level"],
                w.get("etymology"),
                json.dumps(w.get("antonyms", []), ensure_ascii=False),
                json.dumps(w.get("collocations", []), ensure_ascii=False),
                w.get("register"),
                json.dumps(w.get("domainTags", []), ensure_ascii=False),
                w.get("frequencyRank"),
            ))
        con.execute("INSERT INTO words_fts(words_fts) VALUES('rebuild')")
    size_kb = DB_PATH.stat().st_size / 1024
    print(f"\nWrote {len(words)} words → {DB_PATH} ({size_kb:.1f} KB)")

# --------- Main ------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--validate", action="store_true", help="Validate without writing the DB")
    ap.add_argument("--stats", action="store_true", help="Show counts per category/level")
    args = ap.parse_args()

    words, errors = collect_batches()
    if errors:
        print(f"\n{'❌' if errors else '✓'} {len(errors)} error(s):", file=sys.stderr)
        for e in errors:
            print(f"  {e}", file=sys.stderr)
        if not args.stats:
            sys.exit(1)

    if args.stats:
        print_stats(words)
        return

    if args.validate:
        print(f"✓ Validated {len(words)} words across all batches with no errors.")
        return

    if not words:
        print("No words to import.", file=sys.stderr)
        sys.exit(1)
    build_db(words)
    print_stats(words)

if __name__ == "__main__":
    main()
