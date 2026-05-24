# Verbum Word Database — Prompt for Claude Pro

Paste the block below into a NEW Claude Pro chat to start generating.
Reply "next" after each batch. 10 batches total = 5,000 words.

To add more words later in a NEW chat session:
  Replace [EXISTING WORDS] with the contents of existing_words.txt

---

## PASTE THIS INTO CLAUDE PRO:

You are generating a vocabulary database for **Verbum** — an iOS English learning app.

Generate **500 unique English words** per batch. I will reply "next" to get the next batch.
Total: 10 batches = 5,000 words.

**Level per batch:**
- Batches 1–3: `beginner` (everyday A1–A2 vocabulary)
- Batches 4–7: `intermediate` (B1–B2, general/academic/professional)
- Batches 8–10: `expert` (C1–C2, nuanced/literary/specialized)

**Do NOT repeat any word across batches** — remember all words you generate in this conversation.

[EXISTING WORDS — leave empty for first session, paste existing_words.txt here when continuing]:


---

### OUTPUT FORMAT

For each batch output exactly two blocks, nothing else:

### WORDS
```json
[...500 word objects...]
```

### TRANSLATIONS
```json
{"uk": {"<id>": {"d": "<Ukrainian definition>", "e": "<Ukrainian example or null>"}, ...}}
```

---

### WORD OBJECT SCHEMA

```json
{
  "id":              "<UUID v4, lowercase with dashes>",
  "text":            "<English word or two-word phrase>",
  "phonetic":        "<IPA transcription e.g. /wɜːrd/>",
  "partOfSpeech":    "noun | verb | adjective | adverb | phrase | idiom",
  "definition":      "<English definition, max 20 words>",
  "exampleSentence": "<natural sentence using the word, or null>",
  "synonyms":        ["syn1", "syn2"],
  "category":        "<see list below>",
  "level":           "beginner | intermediate | expert",
  "isBookmarked":    false,
  "isLiked":         false,
  "isNew":           false,
  "etymology":       "<origin language + root meaning — required for expert, null for others>"
}
```

**Categories** (pick exactly one per word):
`Food` `Travel` `Technology` `Business` `Nature` `Health` `Art`
`Science` `Social` `Daily Life` `Academic` `Finance` `Law` `Sports` `Emotion` `Communication`

**Rules:**
- `phonetic` is always required — never empty or null
- `etymology` — required for expert words, null for beginner/intermediate
- `isBookmarked`, `isLiked`, `isNew` — always false
- Max 75 words (15%) from any single category per batch
- All 500 words in a batch must be unique from each other and from all previous batches

**TRANSLATIONS rules:**
- Use the same `id` as in the words JSON
- `d` = natural Ukrainian translation of the English definition
- `e` = Ukrainian translation of `exampleSentence`, or null if exampleSentence is null
- Do not include the English word itself in the Ukrainian text

---

Start with **Batch 1 of 10 — beginner**.
