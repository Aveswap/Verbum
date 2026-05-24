#!/usr/bin/env python3
"""
Verbum word database generator.
Calls Claude API in a loop — no manual iterations needed.

Usage:
    pip install anthropic
    export ANTHROPIC_API_KEY=sk-...
    python generate_words.py

Output: words.db (SQLite) ready to host on CDN.
"""

import anthropic
import sqlite3
import json
import uuid
import os
import time
import re
from pathlib import Path

# ── Config ────────────────────────────────────────────────────────────────────

WORDS_PER_BATCH  = 500
TOTAL_WORDS      = 50_000
TOTAL_BATCHES    = TOTAL_WORDS // WORDS_PER_BATCH   # 100
DB_PATH          = Path(__file__).parent / "words.db"
PROGRESS_PATH    = Path(__file__).parent / "progress.json"

LEVEL_BATCHES = {
    "beginner":     range(1,  27),   # batches  1-26  → 13 000 words
    "intermediate": range(27, 75),   # batches 27-74  → 24 000 words
    "expert":       range(75, 101),  # batches 75-100 → 13 000 words
}

BATCH_PROMPT = """\
You are building a vocabulary database for an iOS English learning app called Verbum.

Generate exactly {count} unique English words for Batch {batch} of {total}.
Level for this batch: {level}

OUTPUT — two JSON blocks, nothing else:

### WORDS
```json
[ ...{count} word objects... ]
```

### TRANSLATIONS
```json
{{ "uk": {{ "<id>": {{ "d": "<Ukrainian definition>", "e": "<Ukrainian example or null>" }}, ... }} }}
```

WORD OBJECT SCHEMA (all fields required unless marked optional):
{{
  "id":              "<UUID v4 lowercase with dashes>",
  "text":            "<English word>",
  "phonetic":        "<IPA, e.g. /wɜːrd/>",
  "partOfSpeech":    "noun | verb | adjective | adverb | phrase | idiom",
  "definition":      "<English definition, max 20 words>",
  "exampleSentence": "<sentence using the word, or null>",
  "synonyms":        ["syn1", "syn2"],
  "category":        "<one of: Food Travel Technology Business Nature Health Art Science Social Daily Life Academic Finance Law Sports Emotion Communication>",
  "level":           "{level}",
  "isBookmarked":    false,
  "isLiked":         false,
  "isNew":           false,
  "etymology":       "<origin + root — only for expert, else null>"
}}

RULES:
- Do NOT repeat any of these already-used words: {used_sample}
- All {count} words must be different from each other
- "phonetic" is never empty
- etymology is required for expert words, null for others
- Max 15% of batch from any single category
- TRANSLATIONS: translate definition and exampleSentence into natural Ukrainian

Output ONLY the two JSON code blocks. No other text.
"""

# ── Database setup ────────────────────────────────────────────────────────────

def init_db(path: Path) -> sqlite3.Connection:
    con = sqlite3.connect(path)
    con.execute("PRAGMA journal_mode=WAL")
    con.execute("PRAGMA foreign_keys=ON")
    con.executescript("""
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
            etymology       TEXT
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
            content=words, content_rowid=rowid
        );
    """)
    con.commit()
    return con


def insert_batch(con: sqlite3.Connection, words: list[dict], translations: dict):
    with con:
        for w in words:
            synonyms_json = json.dumps(w.get("synonyms", []), ensure_ascii=False)
            con.execute("""
                INSERT OR IGNORE INTO words
                (id, text, phonetic, partOfSpeech, definition, exampleSentence,
                 synonyms, category, level, isBookmarked, isLiked, isNew, etymology)
                VALUES (?,?,?,?,?,?,?,?,?,0,0,0,?)
            """, (
                w["id"], w["text"], w.get("phonetic",""),
                w.get("partOfSpeech",""), w.get("definition",""),
                w.get("exampleSentence"), synonyms_json,
                w.get("category",""), w["level"], w.get("etymology")
            ))

        uk = translations.get("uk", {})
        for word_id, t in uk.items():
            if not isinstance(t, dict): continue
            con.execute("""
                INSERT OR IGNORE INTO translations (word_id, lang, definition, example)
                VALUES (?, 'uk', ?, ?)
            """, (word_id, t.get("d",""), t.get("e")))

        con.execute("INSERT INTO words_fts(words_fts) VALUES('rebuild')")


def used_words(con: sqlite3.Connection) -> set[str]:
    rows = con.execute("SELECT text FROM words").fetchall()
    return {r[0].lower() for r in rows}


def word_count(con: sqlite3.Connection) -> int:
    return con.execute("SELECT COUNT(*) FROM words").fetchone()[0]

# ── Claude call ───────────────────────────────────────────────────────────────

def parse_response(text: str) -> tuple[list[dict], dict]:
    words_match = re.search(r"### WORDS\s*```json\s*(.*?)```", text, re.DOTALL)
    trans_match  = re.search(r"### TRANSLATIONS\s*```json\s*(.*?)```", text, re.DOTALL)
    words = json.loads(words_match.group(1)) if words_match else []
    trans = json.loads(trans_match.group(1)) if trans_match else {}
    return words, trans


def level_for_batch(batch: int) -> str:
    for level, r in LEVEL_BATCHES.items():
        if batch in r:
            return level
    return "intermediate"


def generate_batch(client: anthropic.Anthropic, batch: int, used: set[str]) -> tuple[list, dict]:
    level = level_for_batch(batch)
    # Send a sample of used words to help Claude avoid repeats (keep prompt short)
    used_sample = ", ".join(list(used)[:200]) if used else "none yet"

    prompt = BATCH_PROMPT.format(
        count=WORDS_PER_BATCH,
        batch=batch,
        total=TOTAL_BATCHES,
        level=level,
        used_sample=used_sample,
    )

    response = client.messages.create(
        model="claude-opus-4-7",   # most capable for large structured output
        max_tokens=8192,
        messages=[{"role": "user", "content": prompt}]
    )
    return parse_response(response.content[0].text)

# ── Progress tracking ─────────────────────────────────────────────────────────

def load_progress() -> int:
    if PROGRESS_PATH.exists():
        return json.loads(PROGRESS_PATH.read_text()).get("last_batch", 0)
    return 0


def save_progress(batch: int):
    PROGRESS_PATH.write_text(json.dumps({"last_batch": batch}))

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        raise SystemExit("Set ANTHROPIC_API_KEY environment variable")

    client = anthropic.Anthropic(api_key=api_key)
    con    = init_db(DB_PATH)
    start  = load_progress() + 1

    print(f"Database: {DB_PATH}")
    print(f"Starting from batch {start} of {TOTAL_BATCHES}")
    print(f"Words already in DB: {word_count(con)}\n")

    for batch in range(start, TOTAL_BATCHES + 1):
        used = used_words(con)
        level = level_for_batch(batch)
        print(f"[{batch:3}/{TOTAL_BATCHES}] {level:12} | words in DB: {len(used)}", end=" → ", flush=True)

        try:
            words, translations = generate_batch(client, batch, used)
            # Filter duplicates the model missed
            words = [w for w in words if w.get("text","").lower() not in used]
            insert_batch(con, words, translations)
            save_progress(batch)
            print(f"inserted {len(words)} words")
        except Exception as e:
            print(f"ERROR: {e}")
            print("Retrying in 30s…")
            time.sleep(30)
            # retry once
            try:
                words, translations = generate_batch(client, batch, used)
                words = [w for w in words if w.get("text","").lower() not in used]
                insert_batch(con, words, translations)
                save_progress(batch)
                print(f"retry OK — inserted {len(words)} words")
            except Exception as e2:
                print(f"Retry failed: {e2} — skipping batch {batch}")

        # Respect API rate limits
        time.sleep(2)

    total = word_count(con)
    print(f"\nDone! Total words in DB: {total}")
    print(f"Database saved to: {DB_PATH}")
    print("Upload words.db to your CDN and update DatabaseDownloadManager.remoteURL")


if __name__ == "__main__":
    main()
