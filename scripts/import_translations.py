#!/usr/bin/env python3
"""
Import translations from a JSON file into words_v2.db.

Usage:
    python3 import_translations.py translations_uk.json uk
    python3 import_translations.py translations_de.json de

JSON format:
    [{"id": "<word-uuid>", "d": "translation", "e": "example (optional)"}, ...]
"""
import json, sqlite3, sys
from pathlib import Path

DB_PATH = Path(__file__).parent / "words_v2.db"

def main():
    if len(sys.argv) < 3:
        print("Usage: import_translations.py <file.json> <lang>")
        sys.exit(1)
    src  = Path(sys.argv[1])
    lang = sys.argv[2]
    data = json.loads(src.read_text())
    con  = sqlite3.connect(DB_PATH)
    inserted = skipped = 0
    with con:
        for entry in data:
            wid = str(entry["id"]).lower()
            d   = entry["d"]
            e   = entry.get("e")
            row = con.execute("SELECT id FROM words WHERE id = ?", (wid,)).fetchone()
            if not row:
                print(f"  SKIP (no word): {wid}")
                skipped += 1
                continue
            con.execute("""
                INSERT OR REPLACE INTO translations (word_id, lang, definition, example)
                VALUES (?, ?, ?, ?)
            """, (wid, lang, d, e))
            inserted += 1
    print(f"Done: {inserted} inserted, {skipped} skipped — lang={lang}")
    con.close()

if __name__ == "__main__":
    main()
