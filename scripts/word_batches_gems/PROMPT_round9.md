# Deep-research prompt — 100 new "wow" words (round 9)

You are a lexicographer curating words for **Verbum**, an English-vocabulary
app. I need **100 new "wow" words** — rare, beautiful, surprising words that make
an educated native English speaker think *"I can't believe there's a word for
that."* Deliver the result as a single JSON file (schema + rules below).

## THE BAR: what "wow" means here

Each word must be at least one of:

- a precise word for a feeling/situation everyone knows but can't name
  (e.g. petrichor, sonder, l'esprit de l'escalier);
- gorgeous to say or look at (e.g. susurration, mellifluous, chatoyant);
- charmingly strange / playful (e.g. collywobbles, snollygoster, hugger-mugger);
- evocative and poetic (e.g. gloaming, halcyon, alpenglow).

No SAT-prep filler, no merely "uncommon" everyday words. If a literate adult
wouldn't be delighted to learn it, cut it.

## HARD RULES (a word that breaks any of these is rejected)

1. **Must be a real English headword** in at least ONE of: Oxford English
   Dictionary, Merriam-Webster, or Collins. State which one in the etymology.
   Naturalized loanwords that have become English headwords are fine
   (e.g. schadenfreude, zeitgeist, frisson).
2. **Mix: 95% "Variant A", 5% "Variant B".**
   - Variant A = genuine English-dictionary headwords (the default — ~95 words).
   - Variant B = iconic foreign "untranslatables" NOT yet in English dictionaries,
     but only world-famous, evocative ones (~5 words max). These are flavour, not
     the substance. Do not pad the list with obscure foreign terms.
3. **No duplicates.** None of the 362 words in the EXCLUDE list below, and no
   simple inflections of them (plural/-ing/-ly variants count as duplicates).
4. **Every word needs a natural example sentence** that shows the meaning in use —
   a real sentence, not a definition restated.
5. **English/Latin script only**, UTF-8. No untransliterated CJK/Cyrillic/etc.
6. **Accurate definitions.** No invented or folk-etymology "dictionary" words
   (no "the smell of old books"-type fabrications). If you can't cite a real
   dictionary, drop it.

## OUTPUT FORMAT

Return ONE JSON array of 100 objects. Each object EXACTLY these keys:

```json
{
  "text": "threnody",
  "phonetic": "/ˈθrɛnədi/",
  "partOfSpeech": "noun",
  "definition": "A song or poem of lamentation for the dead.",
  "exampleSentence": "The composer wrote a quiet threnody for the flood's victims.",
  "synonyms": "dirge, lament, requiem, elegy",
  "antonyms": "",
  "category": "General",
  "etymology": "From Greek 'threnoidia' (threnos 'lament' + oide 'song'); in English from the 17th c. and in Merriam-Webster.",
  "register": "formal",
  "domainTags": "grief, music, poetic",
  "language": "English",
  "freePool": false
}
```

Field rules:

- `text`: lowercase unless a proper noun.
- `phonetic`: IPA in slashes.
- `partOfSpeech`: one of noun / verb / adjective / adverb / interjection / phrase.
- `synonyms`, `antonyms`, `domainTags`: comma-separated string ("" if none).
- `category`: one of — General, Nature, Emotions, People, Society, Time,
  Language, Art, Mind, Movement. Pick the single best fit.
- `etymology`: MUST name the dictionary it appears in (OED / Merriam-Webster /
  Collins), or for the ~5 Variant-B words, state it's a foreign untranslatable
  and name the source language.
- `register`: one of — neutral, formal, informal, literary, archaic, dialectal.
- `language`: always "English".
- `freePool`: false for all (I'll choose free vs premium later).

Output ONLY the JSON array — no prose, no markdown fences.

## EXCLUDE (already in the app — do not return any of these or their inflections)

abligurition, absquatulate, acedia, adumbrate, aegyo, aglet, aiblins, alpenglow, amanuensis, ambrosial, ammil, anagnorisis, anemoia, anon, antelucan, apace, apanthropy, apothegm, apotheosis, apricity, askance, ataraxia, balter, betimes, bibulous, bloviate, bonhomie, borborygmus, brio, brontide, brown study, brumous, bubkes, bumptious, cachinnate, caesura, caliginous, callipygian, cark, catachresis, cattywampus, causerie, chatoyant, chiaroscuro, chthonic, chuffed, clepsydra, clinomania, clinquant, cockamamie, collieshangie, collop, collywobbles, comestible, compersion, concinnous, contretemps, coorie, coruscate, cosset, coup de foudre, couthie, crapulent, crepitate, crepuscular, cromulent, curglaff, curmudgeon, cwtch, cynosure, daebak, deasil, defenestration, deipnosophist, deliquesce, demesne, deshabille, desiderium, diapason, diaphanous, dimpsy, dolce far niente, drugget, dudgeon, duende, dwale, dwam, dépaysement, earworm, effulgence, eggcorn, eldritch, embiggen, eminence grise, ensorcell, epeolatry, estivate, esurient, eucatastrophe, eudaimonia, exaltation, factotum, fantod, fardel, ferrule, fillip, filotimo, fissiparous, flibbertigibbet, flummery, flâneur, fogbow, frangible, frisson, fugacious, fulminate, funambulist, fuscous, gadabout, gallus, galumph, gazump, gemütlichkeit, geosmin, gigglemug, gigil, girandole, glisk, gloaming, gobbledygook, gobemouche, gobsmacked, gongoozler, gormless, gowpen, graupel, griffonage, grok, groke, gulosity, gökotta, haar, halcyon, hangry, hesternal, higgledy-piggledy, hikikomori, hiraeth, hodophile, hornswoggle, hugger-mugger, hurkle-durkle, hypnagogic, iktsuarpok, imbroglio, ineffable, ineluctable, insouciant, interregnum, inveigle, irenic, jammy, jayus, jolie laide, jolly-timbered, jugaad, kilig, koi no yokan, komorebi, kopfkino, kummerspeck, kvell, l'esprit de l'escalier, lacuna, lagniappe, lambent, lapidary, levanter, limerence, liminal, limn, lithops, logorrhea, longueur, louche, lucubrate, lucubration, ludic, luftmensch, mamihlapinatapai, mansuetude, martinet, matutinal, mawkish, meet-cute, melisma, mellifluous, mizzle, mondegreen, mono no aware, mooncalf, moonglade, mordant, mountebank, mudlark, mugwump, mukbang, mumpsimus, murmuration, mångata, naches, nacreous, nepenthe, nephology, nesh, nidor, niksen, noctilucent, noctivagant, nudiustertian, numinous, nunchi, nyctophilia, nympholepsy, obloquy, obnubilate, omnishambles, oneiric, opsimath, orphic, paduasoy, palimpsest, pandiculation, pasalubong, pawky, peely-wally, pellucid, pentimento, penumbra, peradventure, peregrinate, perforce, persiflage, petrichor, philander, plangent, pococurante, poltroon, popinjay, pridian, psithurism, purlicue, purlieu, querencia, quiddity, quidnunc, quietus, quockerwodger, quotidian, raconteur, raillery, ratiocination, rebarbative, recrudescence, redolent, refulgence, resistentialism, respair, retrouvailles, reverie, rodomontade, roke, sangfroid, sapid, sapient, saturnine, scapegrace, schlimazel, scripturient, scurryfunge, seiche, selcouth, sempiternal, serendipity, sesquipedalian, sillage, sisu, sitzfleisch, skinship, smaragdine, smelfungus, smeuse, smicker, smirr, snickersnee, snollygoster, snowbroth, sobremesa, solivagant, somniloquy, sonder, sophrosyne, soupçon, spindrift, spoonerism, sprezzatura, stramash, stravaig, stridulation, sub rosa, supernaculum, susurration, susurrus, sybarite, tampo, tantivy, tartle, tatterdemalion, tenebrous, termagant, tessitura, threnody, tintinnabulation, treppenwitz, tsundoku, twee, twitten, ucalegon, uhtceare, ultracrepidarian, umbrage, utepils, uxorious, vade mecum, valetudinarian, vatic, velleity, verklempt, vertiginous, vespertine, viand, virga, wabbit, wabi-sabi, wamble, wassail, wastrel, weltschmerz, widdershins, williwaw, willy-nilly, winsome, wlonk, woolgathering, yclept, zawn, zephyr, zhuzh, zugzwang, zwer, à la belle étoile

---

**When done:** save the result to `scripts/word_batches_gems/gems_round9.json`
(a file on disk — do NOT paste into chat; chat paste corrupts the IPA/accented
characters into Ã/Â mojibake). I'll then dedup, validate, bump the DB version,
and import.
