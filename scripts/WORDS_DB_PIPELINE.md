# Verbum — 1,000 Word Database Pipeline

End-to-end guide for generating the production word database, validating it, and shipping it to the app via CDN.

---

## 1. Distribution (1,000 words)

| Level | Count | Share | Notes |
|-------|------:|------:|-------|
| Beginner     | 300 | 30 % | Free tier. Frequency rank 1–3000 |
| Intermediate | 450 | 45 % | Main locked tier. Rank 3000–8000 |
| Expert       | 250 | 25 % | Specialist + rare. Rank 8000+ |

Spread across 12 categories with caps in `PLAN` inside `generate_1000_words.py`.

---

## 2. Generation

```bash
cd Verbum/scripts
pip install anthropic
export ANTHROPIC_API_KEY=sk-ant-...
python generate_1000_words.py
```

- Uses **claude-opus-4-7** (best accuracy for etymologies and IPA)
- One API call per `(category, level)` slice; ~36 calls total
- **Resumable**: progress is saved in `progress_v2.json`. Re-run on failure picks up where it left off.
- **De-duplicating**: the script feeds already-generated words back into the prompt so the model doesn't repeat itself

Approximate cost: with Opus 4.7 input ~$20/M and output ~$80/M tokens, ~36 calls × ~12k output tokens ≈ ~430k output tokens ≈ **$35**.

---

## 3. Validation

```bash
python generate_1000_words.py --validate
```

Checks every row for:
- UUID v4 format
- IPA in `/.../` slashes
- `partOfSpeech` ∈ {noun, verb, adjective, adverb, phrase, idiom}
- `register` ∈ {formal, informal, neutral, slang, archaic}

Etymology accuracy needs a manual second pass — cross-reference against:
- https://www.etymonline.com
- https://en.wiktionary.org

A future automated check could call Wiktionary's API for a sample.

---

## 4. Translations

`generate_1000_words.py` only emits English. To populate `translations` table for additional languages:

```bash
python generate_translations.py --langs uk,es,fr,de,pt,it,pl,zh,ja,ko,ar,tr,hi
```

(You will need to write this — recommended structure: read each row from `words.db`, batch 50 rows per Claude call, ask for `definition` + `example` in the target language, INSERT into `translations`.)

For launch with Ukrainian only, the existing `Verbum/Resources/translations.json` is the source of truth — generate from `words_v2.db` once via:

```bash
python export_translations_json.py uk > Verbum/Resources/translations.json
```

---

## 5. Hosting

Upload `words_v2.db` to a CDN. Cheapest options:

| Provider | Bandwidth pricing | Setup difficulty |
|----------|-------------------|------------------|
| Cloudflare R2 | egress free | Easy — public bucket + public URL |
| AWS S3 + CloudFront | egress paid | Medium — needs CloudFront distribution |
| Firebase Storage | egress paid | Easy — public URL via console |

Target URL example: `https://cdn.verbum.app/words_v2.db`

**File size**: ~500 KB compressed, ~2 MB uncompressed. CDN cache hit rate should be ≥ 99 %.

---

## 6. App integration

After upload, edit `Verbum/Core/Data/DatabaseDownloadManager.swift`:

```swift
static let remoteURL = URL(string: "https://cdn.verbum.app/words_v2.db")!
```

Remove the `#warning("Replace …")` line in `startIfNeeded()`.

Optional but recommended — version manifest for future updates:

1. Host `https://cdn.verbum.app/manifest.json`:
   ```json
   { "version": "2.0.0", "url": "https://cdn.verbum.app/words_v2.db", "sha256": "..." }
   ```
2. On launch, fetch the manifest, compare `version` to a UserDefaults key, re-download only if remote is newer.
3. SHA256 verification catches a corrupted download before installing.

---

## 7. Verifying in-app

1. Delete the app to clear the local DB
2. Reinstall and watch `DatabaseStatusBanner` cycle through downloading → installing → done
3. Open the feed: should show beginner words; tap a locked card → premium sheet
4. Open Categories → tap each bucket → confirm wordCount > 0
5. Run StatsView → totalWordCount should be 1000

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `WordDatabase.shared.isAvailable` is false after install | Check sandbox path; the file must end up in app's Documents directory |
| Some etymologies look wrong | Spot-check 10–20 random entries; if >5% off, regenerate that slice |
| FTS search returns no results | `INSERT INTO words_fts(words_fts) VALUES('rebuild')` (the script does this; manual check) |
| Schema mismatch on first install | DEBUG builds erase DB on schema change — toggle that off in WordDatabase.swift before shipping |
