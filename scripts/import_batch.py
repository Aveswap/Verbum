#!/usr/bin/env python3
"""
Verbum — batch importer for manually generated words.

Usage:
  1. Copy Claude's entire response, paste into response.txt
  2. python import_batch.py

Safe to run multiple times — uses INSERT OR IGNORE (no duplicates).
Safe to append new batches to existing DB.

Requirements: pip install (none — stdlib only)
"""

import sqlite3
import json
import re
from pathlib import Path

DB_PATH       = Path(__file__).parent / "words.db"
RESPONSE_FILE = Path(__file__).parent / "response.txt"


# ── DB init ───────────────────────────────────────────────────────────────────

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


# ── Parse Claude response ─────────────────────────────────────────────────────

def parse_response(text: str) -> tuple[list[dict], dict]:
    words_match = re.search(r"### WORDS\s*```json\s*(.*?)```", text, re.DOTALL)
    trans_match  = re.search(r"### TRANSLATIONS\s*```json\s*(.*?)```", text, re.DOTALL)

    if not words_match:
        raise ValueError("Could not find ### WORDS block in response.txt")

    words = json.loads(words_match.group(1).strip())
    trans = json.loads(trans_match.group(1).strip()) if trans_match else {}
    return words, trans


# ── Insert ────────────────────────────────────────────────────────────────────

def insert(con: sqlite3.Connection, words: list[dict], translations: dict) -> int:
    inserted = 0
    with con:
        for w in words:
            synonyms_json = json.dumps(w.get("synonyms", []), ensure_ascii=False)
            cur = con.execute("""
                INSERT OR IGNORE INTO words
                (id, text, phonetic, partOfSpeech, definition, exampleSentence,
                 synonyms, category, level, isBookmarked, isLiked, isNew, etymology)
                VALUES (?,?,?,?,?,?,?,?,?,0,0,0,?)
            """, (
                w["id"], w["text"],
                w.get("phonetic", ""),
                w.get("partOfSpeech", ""),
                w.get("definition", ""),
                w.get("exampleSentence"),
                synonyms_json,
                w.get("category", ""),
                w["level"],
                w.get("etymology"),
            ))
            inserted += cur.rowcount

        uk = translations.get("uk", {})
        for word_id, t in uk.items():
            if not isinstance(t, dict):
                continue
            con.execute("""
                INSERT OR IGNORE INTO translations (word_id, lang, definition, example)
                VALUES (?, 'uk', ?, ?)
            """, (word_id, t.get("d", ""), t.get("e")))

        con.execute("INSERT INTO words_fts(words_fts) VALUES('rebuild')")

    return inserted


# ── Export word list (for continuing in a new chat session) ───────────────────

def export_wordlist(con: sqlite3.Connection):
    rows = con.execute("SELECT text FROM words ORDER BY rowid").fetchall()
    out  = Path(__file__).parent / "existing_words.txt"
    out.write_text(", ".join(r[0] for r in rows), encoding="utf-8")
    return out, len(rows)


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    if not RESPONSE_FILE.exists():
        raise SystemExit(
            "response.txt not found.\n"
            "Paste Claude's full response into scripts/response.txt and re-run."
        )

    con = init_db(DB_PATH)
    before = con.execute("SELECT COUNT(*) FROM words").fetchone()[0]

    raw = RESPONSE_FILE.read_text(encoding="utf-8")
    words, translations = parse_response(raw)
    inserted = insert(con, words, translations)
    after = con.execute("SELECT COUNT(*) FROM words").fetchone()[0]

    print(f"Imported:   {inserted} new words")
    print(f"Skipped:    {len(words) - inserted} duplicates")
    print(f"Total in DB: {after} words")

    wordlist_path, total = export_wordlist(con)
    print(f"\nexisting_words.txt updated ({total} words) — paste into next chat if starting a new session")
    print(f"DB: {DB_PATH}")

    # Clear response.txt so next batch doesn't accidentally re-import
    RESPONSE_FILE.write_text("", encoding="utf-8")
    print("\nresponse.txt cleared — ready for next batch.")


if __name__ == "__main__":
    main()
