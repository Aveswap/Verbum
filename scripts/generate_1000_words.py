#!/usr/bin/env python3
"""
Verbum — 1,000-word database generator (v2 schema).

Produces a `words_v2.db` SQLite file ready to host on CDN and consume via
DatabaseDownloadManager. Schema matches Verbum/Core/Models/Word.swift +
WordDatabase migrations (v1 + v2).

Distribution (matches the audit recommendation):
  300 beginner / 450 intermediate / 250 expert
  spread across 12 categories with the per-bucket caps below.

Usage:
    pip install anthropic
    export ANTHROPIC_API_KEY=sk-ant-...
    python generate_1000_words.py            # full run, resumable via progress.json
    python generate_1000_words.py --validate # re-validate an existing db
"""

import anthropic
import argparse
import json
import os
import re
import sqlite3
import sys
import time
import uuid
from pathlib import Path

# --------- Config ----------------------------------------------------------

CLIENT = anthropic.Anthropic()  # picks up ANTHROPIC_API_KEY
MODEL  = "claude-opus-4-7"      # latest reasoning model — best for accurate etymologies

DB_PATH        = Path(__file__).parent / "words_v2.db"
PROGRESS_PATH  = Path(__file__).parent / "progress_v2.json"

# (category, level, count) — initial seed: 50 free-pool words per level for the
# soft-paywall MVP. Categories below intentionally skip the premium DB-categories
# (Technology / Science / Literature / Society) so the free 50 at each level can
# safely be drawn from non-premium content. Premium content is generated later
# (phase 2) and lives in those four categories.
PLAN = [
    # ─── Beginner: 50 ──
    ("Daily Life & Social",   "beginner", 12),
    ("Emotions & Psychology", "beginner",  8),
    ("Communication",         "beginner",  6),
    ("Body & Health",         "beginner",  6),
    ("Nature & Environment",  "beginner",  6),
    ("Business & Finance",    "beginner",  4),
    ("Food & Culture",        "beginner",  4),
    ("Character",             "beginner",  4),
    # ─── Intermediate: 50 ──
    ("Daily Life & Social",   "intermediate", 10),
    ("Emotions & Psychology", "intermediate", 10),
    ("Communication",         "intermediate",  8),
    ("Body & Health",         "intermediate",  6),
    ("Nature & Environment",  "intermediate",  4),
    ("Business & Finance",    "intermediate",  6),
    ("Food & Culture",        "intermediate",  4),
    ("Character",             "intermediate",  2),
    # ─── Expert: 50 ──
    ("Daily Life & Social",   "expert",  6),
    ("Emotions & Psychology", "expert", 10),
    ("Communication",         "expert",  8),
    ("Body & Health",         "expert",  6),
    ("Nature & Environment",  "expert",  4),
    ("Business & Finance",    "expert",  8),
    ("Food & Culture",        "expert",  4),
    ("Character",             "expert",  4),
]
assert sum(c for _, _, c in PLAN) == 150

LEVEL_FREQ_HINT = {
    "beginner":     "1-3000",
    "intermediate": "3000-8000",
    "expert":       "8000+ (or specialist)",
}

# --------- Prompt ---------------------------------------------------------

SYSTEM_PROMPT = """You are a lexicographer building a vocabulary database for an English learning app.
Generate words in strict JSON format. Each word must be real, commonly used in modern English, and
match the difficulty level specified.

CRITICAL RULES:
- Etymologies must be historically accurate. If genuinely uncertain, write "Origin uncertain."
- Phonetics must be valid IPA notation enclosed in slashes: /ˈwɜːrd/
- Example sentences must use the word naturally, not as an obvious vocabulary exercise
- Synonyms must be real synonyms, not merely related words
- Register must be exactly one of: formal, informal, neutral, slang, archaic
- frequencyRank: rough estimate of word frequency in modern English texts (1 = most common)
- All UUIDs are v4 lowercase with dashes
- Each word must be unique; do not repeat any word the user already gave you

OUTPUT — strict JSON array, no prose, no markdown fences, no commentary.
The array length must equal the requested count exactly.
"""

USER_TEMPLATE = """Generate {count} {level}-level English words for the category "{category}".

Requirements:
- frequencyRank between {freq_hint}
- Mix of nouns (45%), verbs (30%), adjectives (20%), adverbs (5%) — approximate
- At least {etym_count} words should have an interesting (but accurate) etymology
- Each word: 2-3 synonyms, 1-2 antonyms (or [] if none), 1-2 natural collocations
- Register mostly neutral or formal for non-beginner levels

Already used in this run — DO NOT regenerate these:
{used}

JSON schema for each item (do not add extra keys):
{{
  "id":              "uuid-v4",
  "text":            "word",
  "phonetic":        "/IPA/",
  "partOfSpeech":    "noun|verb|adjective|adverb",
  "definition":      "clear definition, 8-20 words",
  "exampleSentence": "natural sentence using the word",
  "synonyms":        ["syn1", "syn2"],
  "antonyms":        ["ant1"],
  "collocations":    ["common phrase 1", "common phrase 2"],
  "category":        "{category}",
  "level":           "{level}",
  "etymology":       "brief accurate origin or null",
  "frequencyRank":   1234,
  "register":        "formal|informal|neutral|slang|archaic",
  "domainTags":      ["domain1", "domain2"]
}}

Return ONLY the JSON array. No other text.
"""

# --------- DB --------------------------------------------------------------

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
    -- v2 schema fields
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
"""

def init_db():
    con = sqlite3.connect(DB_PATH)
    con.execute("PRAGMA journal_mode=WAL")
    con.executescript(DDL)
    con.commit()
    return con

# --------- Validation ------------------------------------------------------

IPA_RE = re.compile(r"^/.+/$")
UUID_RE = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")
VALID_REGISTERS = {"formal", "informal", "neutral", "slang", "archaic"}
VALID_POS = {"noun", "verb", "adjective", "adverb", "phrase", "idiom"}

def validate_word(w: dict, category: str, level: str) -> list[str]:
    errors = []
    for key in ["id", "text", "phonetic", "partOfSpeech", "definition", "synonyms",
                "antonyms", "collocations", "category", "level"]:
        if key not in w:
            errors.append(f"missing field: {key}")
    if "id" in w and not UUID_RE.match(str(w["id"])):
        errors.append(f"bad uuid: {w.get('id')}")
    if "phonetic" in w and not IPA_RE.match(str(w["phonetic"])):
        errors.append(f"bad phonetic: {w.get('phonetic')}")
    if "register" in w and w["register"] is not None and w["register"] not in VALID_REGISTERS:
        errors.append(f"bad register: {w.get('register')}")
    if "partOfSpeech" in w and w["partOfSpeech"] not in VALID_POS:
        errors.append(f"bad partOfSpeech: {w.get('partOfSpeech')}")
    if w.get("category") != category:
        errors.append(f"category mismatch: expected {category}, got {w.get('category')}")
    if w.get("level") != level:
        errors.append(f"level mismatch: expected {level}, got {w.get('level')}")
    return errors

# --------- Generation ------------------------------------------------------

def already_used(con) -> set[str]:
    return {row[0].lower() for row in con.execute("SELECT text FROM words")}

def generate_slice(category: str, level: str, count: int, used: set[str]) -> list[dict]:
    etym_count = max(3, count // 6)
    sample = sorted(used)[:120]  # cap so prompt stays small
    prompt = USER_TEMPLATE.format(
        count=count,
        level=level,
        category=category,
        freq_hint=LEVEL_FREQ_HINT[level],
        etym_count=etym_count,
        used=", ".join(sample) or "(none yet)",
    )
    resp = CLIENT.messages.create(
        model=MODEL,
        max_tokens=16_000,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": prompt}],
        temperature=0.4,
    )
    text = resp.content[0].text.strip()
    # Robust JSON extraction — handle stray fences
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?", "", text).rsplit("```", 1)[0].strip()
    items = json.loads(text)
    if not isinstance(items, list):
        raise ValueError("Expected JSON array at top level")
    return items

def insert_words(con, words: list[dict]):
    with con:
        for w in words:
            con.execute("""
                INSERT OR IGNORE INTO words
                (id, text, phonetic, partOfSpeech, definition, exampleSentence,
                 synonyms, category, level, etymology,
                 antonyms, collocations, register, domainTags, frequencyRank)
                VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
            """, (
                w["id"], w["text"], w["phonetic"], w["partOfSpeech"], w["definition"],
                w.get("exampleSentence"),
                json.dumps(w.get("synonyms", []), ensure_ascii=False),
                w["category"], w["level"],
                w.get("etymology"),
                json.dumps(w.get("antonyms", []), ensure_ascii=False),
                json.dumps(w.get("collocations", []), ensure_ascii=False),
                w.get("register"),
                json.dumps(w.get("domainTags", []), ensure_ascii=False),
                w.get("frequencyRank"),
            ))
        con.execute("INSERT INTO words_fts(words_fts) VALUES('rebuild')")

def load_progress():
    if not PROGRESS_PATH.exists(): return {"done": []}
    return json.loads(PROGRESS_PATH.read_text())

def save_progress(p):
    PROGRESS_PATH.write_text(json.dumps(p, indent=2))

# --------- Main ------------------------------------------------------------

def run():
    con = init_db()
    progress = load_progress()
    done = set(map(tuple, progress["done"]))

    used_words = already_used(con)

    for i, (category, level, count) in enumerate(PLAN, start=1):
        if (category, level) in done:
            print(f"[{i:>2}/{len(PLAN)}] skip already done: {category} / {level}")
            continue

        print(f"[{i:>2}/{len(PLAN)}] generating {count} × {level} for {category}...")
        for attempt in range(3):
            try:
                items = generate_slice(category, level, count, used_words)
                errors = []
                for w in items:
                    errors.extend(validate_word(w, category, level))
                if errors:
                    print(f"  validation failed (attempt {attempt+1}): {errors[:5]}")
                    continue
                insert_words(con, items)
                used_words.update(w["text"].lower() for w in items)
                done.add((category, level))
                progress["done"] = [list(t) for t in done]
                save_progress(progress)
                print(f"  ✓ inserted {len(items)} words")
                break
            except Exception as e:
                print(f"  error (attempt {attempt+1}): {e}")
                time.sleep(2 * (attempt + 1))
        else:
            print(f"  FAILED after 3 attempts: {category} / {level}")

    total = con.execute("SELECT COUNT(*) FROM words").fetchone()[0]
    print(f"\nDone. Words in DB: {total}")
    print(f"Output: {DB_PATH}")
    print("\nNext: upload words_v2.db to your CDN and update")
    print("`DatabaseDownloadManager.remoteURL` in the iOS target.")

def validate_only():
    con = sqlite3.connect(DB_PATH)
    rows = con.execute("SELECT id, text, phonetic, partOfSpeech, category, level FROM words").fetchall()
    issues = 0
    for r in rows:
        wid, text, phon, pos, cat, lvl = r
        if not UUID_RE.match(wid): print(f"bad uuid: {text} ({wid})"); issues += 1
        if not IPA_RE.match(phon):  print(f"bad ipa: {text} ({phon})"); issues += 1
        if pos not in VALID_POS:    print(f"bad pos: {text} ({pos})"); issues += 1
    print(f"\nValidated {len(rows)} rows, {issues} issues found.")

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--validate", action="store_true")
    args = ap.parse_args()
    if args.validate:
        validate_only()
    else:
        if "ANTHROPIC_API_KEY" not in os.environ:
            print("Set ANTHROPIC_API_KEY first.", file=sys.stderr)
            sys.exit(1)
        run()
