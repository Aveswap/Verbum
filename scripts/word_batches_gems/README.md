# Gem batches (curated "wow-tier" standalone words)

Drop the deep-research output here as one or more **clean UTF-8** `*.json` files (e.g.
`gems_en.json`, `gems_de.json`, `gems_uk.json`, or a single `gems.json`). Each file is a JSON
array using the deep-research field names:

    text, phonetic, partOfSpeech, definition, exampleSentence, synonyms, category, level,
    etymology, register, language    (+ optional "freePool": true, "frequencyRank": <int>)

Then, **after** running build_de_catalog.py / build_uk_catalog.py:

    python3 import_gems.py --validate   # check normalization + dedup, write nothing
    python3 import_gems.py              # import + copy to Resources
    python3 validate_content.py         # must stay errors=0
    # then bump WordDatabase.bundledDBVersion

`import_gems.py` normalizes language names → en/de/uk, part-of-speech → canonical
noun/verb/adjective/adverb, synonyms → JSON array, cleans phonetics, assigns frequencyRank, and
skips any word whose lemma already exists in that language (keeps lemmas distinct).

⚠️ Do NOT paste the research text straight from a chat — it often arrives mojibake'd
(UTF-8 misread as Latin-1), which corrupts Cyrillic and IPA. Save the raw output to a file as
UTF-8 first.
