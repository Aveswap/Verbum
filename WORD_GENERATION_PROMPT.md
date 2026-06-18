# Verbum — Word Generation Prompt

Paste **everything below the `---`** into ChatGPT / Claude / Gemini to generate a fresh batch
of curated "wow-tier" gem words for the Verbum vocabulary catalogue.

**Pipeline after generation:**
1. Save the model's JSON output to `scripts/word_batches_gems/gems_roundN.json` (next available N).
2. Run `python3 scripts/import_gems.py --validate` (parse + normalize check, no DB write).
3. Run `python3 scripts/import_gems.py` to insert + copy the new DB into `Verbum/Resources/`.
4. Bump `DB_VERSION` in `WordDatabase.swift` if you want existing users to re-seed on next launch.

**Snapshot used for the exclusion list:** git tag `archive-2026-06-18` — DB has **434 English
gem words**. Regenerate with `sqlite3 Verbum/Resources/words_v2.db "SELECT text FROM words
ORDER BY text;"` before each new batch.

---

# Verbum — generate a curated batch of rare, beautiful English words

## Mission

I run **Verbum**, a swipe-feed iOS app that teaches one rare English word per day. The
catalogue is "wow-tier": uncommon, evocative, dictionary-attested words that make a learner
stop and feel something — *petrichor, hiraeth, sonder, sprezzatura, mångata*. We are NOT a
TOEFL/IELTS app. We are NOT teaching common vocabulary. Every word must earn its place by
being either *gorgeous*, *strange*, or *naming a feeling/phenomenon English speakers don't
have a common word for*.

Generate **a batch of 70 new gem words** that fit this aesthetic and are NOT already in the
catalogue (see exclusion list at the bottom).

## Quality bar — every word must pass ALL of these

1. **Attested.** The word appears as a headword in at least one mainstream English
   dictionary (Merriam-Webster, OED, Collins, Cambridge, dictionary.com) OR is a well-
   documented loanword used in respected English-language writing (e.g. *hiraeth* from
   Welsh, *gemütlichkeit* from German, *mamihlapinatapai* from Yagán). If you cannot name
   a real source, drop the word.
2. **Rare.** A literate native English speaker should *not* know it offhand. Common
   "SAT vocabulary" (*ephemeral, ubiquitous, juxtapose, esoteric*) is **forbidden** —
   that's not what Verbum is. Aim for words that surprise even avid readers.
3. **Evocative.** It must name a *specific* feeling, phenomenon, or image — not a generic
   abstract concept. *Apricity* (warmth of winter sun) is in. *Beautiful* is out.
4. **Standalone.** No hyphenated multi-word phrases unless they are dictionary-attested
   compounds (*brown study*, *meet-cute*, *higgledy-piggledy* — fine). No proper nouns.
5. **Not on the exclusion list** at the bottom of this prompt.

## Output format — JSON array, one object per word

The import script (`scripts/import_gems.py`) parses this exact shape. Stick to it strictly.

```json
[
  {
    "text": "petrichor",
    "phonetic": "/ˈpɛtrɪkɔːr/",
    "partOfSpeech": "noun",
    "definition": "The pleasant earthy smell produced when rain falls on dry soil.",
    "exampleSentence": "After the first storm of August, the whole valley smelled of petrichor.",
    "synonyms": "earth-scent, geosmin-aroma",
    "antonyms": "",
    "category": "Nature",
    "etymology": "Coined 1964 by Australian researchers Bear and Thomas from Greek 'petra' (stone) + 'ichor' (the fluid that flows in the veins of the gods); a headword in Merriam-Webster.",
    "register": "neutral",
    "domainTags": "weather, smell, nature",
    "language": "English",
    "freePool": false
  }
]
```

### Field rules

| Field | Required | Notes |
|---|---|---|
| `text` | yes | Lowercase, unaccented form OK; loanwords keep their diacritics (*dépaysement*). |
| `phonetic` | yes | IPA only, between slashes `/…/`. No "(non-rhotic)" notes — just the IPA. |
| `partOfSpeech` | yes | One of: `noun`, `verb`, `adjective`, `adverb`. (The app abbreviates these to `(n.)` `(v.)` `(adj.)` `(adv.)`.) Most gems are nouns. |
| `definition` | yes | ONE sentence, ≤ 25 words. Plain English. No "see also". |
| `exampleSentence` | yes | ONE sentence using the word in a natural, evocative context. Must contain the headword as a whole token (the FillGap quiz searches for it). |
| `synonyms` | optional | Comma-separated string OR JSON array. Real near-synonyms only, no padding. Empty string `""` if none. |
| `antonyms` | optional | Same shape as synonyms. Usually empty for gems. |
| `category` | yes | EXACTLY one of the values below — see Categories. |
| `etymology` | yes | One sentence. Must end by naming the dictionary source: `…; a headword in Merriam-Webster.` Without a source, the entry is rejected by the curator. |
| `register` | yes | One of: `formal`, `neutral`, `informal`, `slang`, `archaic`. Most gems are `formal` or `neutral`; whimsical Scots/dialect gems are `archaic` or `informal`. |
| `domainTags` | optional | 2–4 comma-separated tags (`weather, smell, nature`). Lowercase. |
| `language` | yes | Always `English`. |
| `freePool` | optional | `true` puts the word in the first-50 free preview. Default `false`. Mark at most 5 per batch as `true`, and only if the word is unusually accessible/charming. |

### Categories (use these EXACTLY — case-sensitive)

Current catalogue distribution after `archive-2026-06-18`:

| Category | Count | Examples we already have |
|---|---|---|
| **General** | 149 | *afterwit, peradventure, perforce, willy-nilly* |
| **Character** | 39 | *curmudgeon, popinjay, scapegrace, martinet* |
| **Communication** | 37 | *adumbrate, persiflage, raillery, taradiddle* |
| **Emotions** | 33 | *anhedonia, hiraeth, saudade, weltschmerz* |
| **People** | 33 | *flâneur, gadabout, raconteur, sybarite, boulevardier* |
| **Nature** | 34 | *petrichor, mångata, gegenschein, syzygy, mammatus, parhelion* |
| **Psychology** | 24 | *iktsuarpok, limerence, querencia, abulia, akrasia, cathexis* |
| **Food** | 19 | *abligurition, kummerspeck, mukbang, prandial, esculent* |
| **Art** | 19 | *chiaroscuro, impasto, sfumato, craquelure, tenebrism, contrapposto* |
| **Body** | 17 | *borborygmus, glabella, philtrum, canthus, lunula, hallux* |
| **Language** | 19 | *eggcorn, interrobang, mondegreen, paronomasia, zeugma, calque* |
| **Time** | 14 | *brumal, gloaming, hesternal, crepuscule, whilom, overmorrow* |
| **Literature** | 14 | *anagnorisis, aposiopesis, ekphrasis, clerihew, festschrift, palinode* |
| **Society** | 13 | *gazump, gongoozler, anomie, comity, sodality, commonweal* |
| **Science** | 13 | *albedo, analemma, geosmin, triboluminescence, fulgurite* |
| **Movement** | 12 | *galumph, gambol, tittup, skirr, lollop, pronk, volplane* |
| **Mind** | 12 | *eidetic, hypnagogic, reverie, metanoia, noesis, qualia* |

**Under-represented categories I'd love more of:** Emotions (gem-tier, dictionary-attested),
Communication (beyond rhetorical-figure overlap), Food, Art, Body, Society, Science, Mind,
Time. Movement and Literature are now well-stocked — only add MORE of those if the word is a
clear standout. Avoid more "General" entries; the bucket is already overweight.

## Anti-patterns — automatic rejects

- Any word a college-educated native speaker likely knows (*serendipitous, ephemeral,
  juxtapose, ubiquitous, esoteric, melancholy, nostalgia* — too common; we already have
  *serendipity* but more common words are out).
- Made-up neologisms with no dictionary entry. *We don't ship vibes-only words.* If you
  can't cite a source in `etymology`, kill it.
- Technical jargon with no metaphorical use (*phenethylamine, hyponatremia*) — boring,
  not evocative.
- Slurs, ethnic stereotypes, religious mockery. We've seen the wreckage.
- Loanwords whose only English citation is one ironic tweet. Real usage in literature or
  journalism only.
- Hyphenated *compound phrases* that aren't dictionary-attested (e.g. *deep-feeling*, *moon-
  glow*). Dictionary compounds like *brown study*, *meet-cute*, *higgledy-piggledy* are OK.

## How to think before writing

1. Brainstorm 60 candidates from your mental list of obscure dictionary headwords across
   the suggested categories.
2. For each, mentally check the exclusion list at the bottom — drop duplicates.
3. For each remaining, mentally check: would a Verbum user say *"oh wow, I didn't know
   there was a word for that"*? If no, drop.
4. Pick the top 30. Spread across the under-represented categories.
5. Write the JSON. One sentence per definition, one sentence per example. Be precise.
6. Etymology MUST cite a dictionary or attested literary source by name.

## Exclusion list — these 504 words are already in the catalogue, DO NOT GENERATE THEM

abecedarian, abligurition, absquatulate, abulia, acedia, adumbrate, afterwit, aglet, aiblins, akrasia, albedo, alpenglow, amanuensis, ambrosial, ammil, anagnorisis, analemma, anfractuous, anhedonia, anomie, anon, antelucan, apace, apanthropy, apophenia, aposiopesis, apothegm, apotheosis, apricity, askance, ataraxia, aubade, aureole, balter, betimes, bibulous, billingsgate, bloviate, bonhomie, borborygmus, boulevardier, boustrophedon, brattle, brio, brocken spectre, brontide, brown study, brumal, brumous, bubkes, bumbershoot, bumfuzzle, bumptious, cachinnate, caesura, caliginous, callipygian, calque, canthus, capriole, cark, cat's-paw, catachresis, cathexis, cattywampus, causerie, celadon, cento, chatoyant, chiaroscuro, chinoiserie, chthonic, chuffed, clepsydra, clerihew, clinomania, clinquant, cockalorum, cockamamie, cockcrow, codswallop, collieshangie, collop, collywobbles, colophon, coloratura, comestible, comity, commonweal, compunctious, concinnous, contrapposto, contretemps, coorie, coruscate, cosset, couthie, crapulent, craquelure, crepitate, crepuscular, crepuscule, cromulent, crwth, curglaff, curmudgeon, curvet, cwtch, cynosure, deasil, defenestration, deipnosophist, deliquesce, demesne, deshabille, desiderium, diapason, diaphanous, dimpsy, divagate, divulsion, donnybrook, drugget, dudgeon, duende, dwale, dwam, dépaysement, earthshine, earworm, effulgence, eggcorn, eidetic, ekphrasis, eldritch, eleutheromania, embiggen, ensorcell, envoi, epeolatry, epigraph, epithalamium, erewhile, erinaceous, esculent, esemplastic, estivate, esurient, eucatastrophe, eudaimonia, eventide, exaltation, factotum, fantod, fardel, fata morgana, fernweh, ferrule, festschrift, fillip, filotimo, fipple, firn, fissiparous, flapdoodle, flibbertigibbet, flummery, flâneur, fogbow, forenoon, frangible, frisson, frondescence, fugacious, fulgurite, fuliginous, fulminate, funambulist, fuscous, gadabout, gallus, galumph, gambado, gamboge, gambol, gardyloo, gazump, gegenschein, gemütlichkeit, geosmin, gigglemug, girandole, glabella, glisk, glister, gloaming, gnathion, gobbledygook, gobemouche, gobsmacked, gongoozler, gormless, gowpen, graupel, griffonage, grisaille, grok, groke, guillemet, gulosity, gökotta, haar, halcyon, hallux, hangry, heiligenschein, hesternal, hiemal, higgledy-piggledy, hikikomori, hiraeth, hoarfrost, hodophile, hornswoggle, horologe, hugger-mugger, hurkle-durkle, hypnagogic, hypnopompic, iktsuarpok, imbroglio, impasto, incunabulum, ineffable, ineluctable, insouciant, interregnum, interrobang, inveigle, irenic, isabelline, jammy, japanning, jolly-timbered, jugaad, komorebi, kummerspeck, kvell, lacuna, lagniappe, lambent, lapidary, lechatelierite, levanter, limerence, liminal, limn, lithops, logorrhea, lollop, longueur, louche, lucubrate, lucubration, ludic, luftmensch, lunula, mamihlapinatapai, mammatus, mansuetude, marcescence, martinet, matutinal, mawkish, meet-cute, melisma, mellifluous, metanoia, milquetoast, mizzle, mondegreen, mooncalf, moonglade, mordant, mountebank, mudlark, mugwump, mukbang, mumpsimus, murmuration, mångata, naches, nacreous, nepenthe, nephology, nesh, nidor, niksen, nimbus, ninnyhammer, niveous, noctilucent, noctivagant, noesis, nudiustertian, numinous, nunchi, nychthemeron, nyctophilia, nympholepsy, obelus, obloquy, obnubilate, octothorpe, omnishambles, omphalos, oneiric, opalescence, opsimath, orphic, overmorrow, oxter, paduasoy, palimpsest, palinode, pandiculation, panjandrum, paramnesia, pareidolia, parhelion, paronomasia, pawky, peely-wally, pellucid, pentimento, penumbra, peradventure, perambulate, peregrinate, perforce, periphrasis, persiflage, petrichor, pettifogger, philander, philtrum, phosphene, pilcrow, plangent, pococurante, poltroon, popinjay, prandial, pridian, pronk, psithurism, purl, purlicue, purlieu, qualia, querencia, quiddity, quidnunc, quietus, quockerwodger, quotidian, raconteur, raillery, ratiocination, ratoon, rebarbative, recrudescence, redolent, refection, refulgence, repoussé, resistentialism, respair, retrouvailles, reverie, rime, rodomontade, roke, saltant, samara, sangfroid, sapid, sapient, sastrugi, saturnine, saudade, scapegrace, scaramouch, schlimazel, scintilla, scripturient, scurryfunge, scuttlebutt, seiche, selcouth, sempiternal, sennight, serein, serendipity, sesquipedalian, sfumato, sgraffito, sillage, sisu, sitzfleisch, skirl, skirr, smaragdine, smelfungus, smeuse, smicker, smirr, snickersnee, snirtle, snollygoster, snool, snowbroth, sobremesa, sodality, solivagant, somniloquy, sophrosyne, sough, soupçon, spindrift, spoonerism, sprezzatura, stramash, stravaig, stridulation, supernaculum, susurration, susurrus, sybarite, syzygy, tantivy, taradiddle, tartle, tatterdemalion, tenebrism, tenebrous, termagant, tessitura, threnody, tintinnabulation, titivate, tittle, tittup, tmesis, toska, tourbillon, triboluminescence, tsundoku, twee, twitten, ucalegon, uhtceare, ultimo, ultracrepidarian, umbrage, utepils, uxorious, valetudinarian, vatic, velleity, verglas, verklempt, vernation, vertiginous, vespertine, viand, virga, virgule, volplane, vomitory, wabbit, wabi-sabi, wamble, wassail, wastrel, welkin, weltschmerz, whiffler, whilom, widdershins, williwaw, willy-nilly, winsome, wlonk, woolgathering, yclept, yestreen, zawn, zephyr, zeugma, zhuzh, zodiacal light, zugzwang, zwer

## Now generate

Produce a JSON array of **70 new gem words** following all rules above. Output **only** the
JSON — no preamble, no commentary, no markdown fences. Just the array.
