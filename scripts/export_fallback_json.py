#!/usr/bin/env python3
"""Regenerate Verbum/Resources/words.json (the brief first-launch fallback served while the
bundled DB seeds) directly from words_v2.db, so its ids / ranks / fields match the real catalogue
exactly — otherwise a swipe during the seed window writes orphan UUIDs into seenWordIds/CloudKit."""
import json, os, sqlite3

HERE = os.path.dirname(os.path.abspath(__file__))
DB = os.path.join(HERE, "words_v2.db")
OUT = os.path.join(HERE, "..", "Verbum", "Resources", "words.json")

def arr(s):
    try:
        v = json.loads(s) if s else []
        return v if isinstance(v, list) else []
    except Exception:
        return []

con = sqlite3.connect(DB)
con.row_factory = sqlite3.Row
rows = con.execute("""
    SELECT id, text, phonetic, partOfSpeech, definition, exampleSentence, synonyms,
           category, etymology, frequencyRank, antonyms, collocations, register, domainTags, language
    FROM words ORDER BY language, frequencyRank
""").fetchall()
con.close()

out = []
for r in rows:
    w = {
        "id": r["id"].upper(),
        "text": r["text"],
        "phonetic": r["phonetic"] or "",
        "partOfSpeech": r["partOfSpeech"] or "",
        "definition": r["definition"],
        "exampleSentence": r["exampleSentence"],
        "synonyms": arr(r["synonyms"]),
        "antonyms": arr(r["antonyms"]),
        "collocations": arr(r["collocations"]),
        "category": r["category"] or "",
        "etymology": r["etymology"],
        "frequencyRank": r["frequencyRank"],
        "domainTags": arr(r["domainTags"]),
        "language": r["language"] or "en",
        "isNew": False,
    }
    if r["register"]:
        w["register"] = r["register"]
    out.append(w)

json.dump(out, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(f"wrote {len(out)} words → {os.path.abspath(OUT)}")
