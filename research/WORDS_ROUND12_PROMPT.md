# Deep-research prompt — 100 new "wow" words (round 12)

> Paste everything below into a deep-research tool. Save the result to a file on disk as
> `gems_round12.json` — do NOT paste it back into chat (chat corrupts the IPA/accented characters
> into Ã/Â mojibake). Then we dedup, validate, bump the DB version, and import.

---

You are a lexicographer curating words for **Verbum**, an iOS app about **beautiful, rare English
words**. Verbum's promise is *"collect the words for feelings you couldn't name."* Users swipe a
TikTok-style feed of gorgeous words, **claim** the ones that move them into a personal lexicon, and
write why each one is theirs. So the words must be **emotionally resonant and delightful**, not dry
trivia.

I need **100 new "wow" words** — rare, beautiful, surprising words that make an educated native
English speaker think *"I can't believe there's a word for that."*

## THE BAR: what "wow" means here
Strongly prefer words that are at least one of:
- a precise name for a **feeling / inner state / human moment** everyone knows but can't name
  (longing, wistfulness, awe, tenderness, restlessness, contentment, bittersweetness);
- **sensory / atmospheric** — light, weather, sound, scent, the textures of the world
  (think *petrichor*, *gloaming*, *susurrus*, *chatoyant*);
- **charmingly strange or playful** to say (think *collywobbles*, *snollygoster*);
- **evocative and poetic**, the kind of word you'd screenshot.

If a literate adult wouldn't be *delighted* to learn it, cut it.

## ⚠️ AVOID these (the catalogue is already over-full of them)
Do **not** return dry/technical "curiosity" words — they dilute the emotional feel of the app:
- rhetoric/grammar terms (e.g. *chiasmus, zeugma, litotes, anaphora*),
- typography/punctuation marks (e.g. *pilcrow, interrobang, octothorpe*),
- anatomy terms (e.g. *hallux, oxter, philtrum*),
- art/craft technique jargon (e.g. *sfumato, impasto, gesso*),
- pure science/math/astronomy jargon (e.g. *apsis, ephemeris, thixotropy*).
Lean **emotional, sensory, poetic, human** instead.

## HARD RULES (a word that breaks any of these is rejected)
1. **Must be a real English headword** in at least ONE of: Oxford English Dictionary, Merriam-
   Webster, or Collins. State which one at the END of the `etymology` field. Naturalized loanwords
   that became English headwords are fine (e.g. *schadenfreude*, *frisson*, *gemütlichkeit*).
2. **Mix: ~95% genuine English-dictionary headwords; ≤5% iconic foreign "untranslatable"
   FEELING-words** (e.g. *sehnsucht*, *saudade*-type), only world-famous evocative ones. Do not pad
   with obscure foreign terms.
3. **No duplicates.** None of the ~574 words in the EXCLUDE list below, and no simple inflections of
   them (plurals / -ing / -ly variants count as duplicates).
4. **Every word needs a natural example sentence** that shows the meaning in use — a real sentence,
   not the definition restated.
5. **English/Latin script only**, UTF-8. No untransliterated CJK/Cyrillic/etc.
6. **Accurate definitions.** No invented or folk-etymology "dictionary" words, and **no blog-coined
   neologisms** (exclude coinages like *sonder*/*anemoia* unless they've entered a real dictionary).

## OUTPUT FORMAT
Return ONE JSON array of 100 objects. Each object EXACTLY these keys:

```json
{
  "text": "hiraeth",
  "phonetic": "/ˈhɪraɪθ/",
  "partOfSpeech": "noun",
  "definition": "A deep, wistful longing for a home or time that is gone or never was.",
  "exampleSentence": "Standing in the empty farmhouse, she was overcome by hiraeth for a childhood that felt half-imagined.",
  "synonyms": "longing, yearning, nostalgia, wistfulness",
  "antonyms": "",
  "category": "Emotions",
  "etymology": "From Welsh, with no exact English equivalent; popularised in English nature writing. Listed in the Oxford English Dictionary.",
  "register": "literary",
  "domainTags": "longing, melancholy, home",
  "language": "English",
  "freePool": false
}
```

Field rules:
- `text`: lowercase unless a proper noun.
- `phonetic`: IPA in slashes.
- `partOfSpeech`: one of noun / verb / adjective / adverb / interjection / phrase.
- `synonyms`, `antonyms`, `domainTags`: comma-separated strings ("" if none).
- `category`: pick the single best fit from — Emotions, Nature, Mind, People, Society, Time,
  Language, Art, Movement, General. (Bias toward Emotions / Nature / Mind.)
- `etymology`: write it as **interesting origin trivia** (where it came from, who coined it, a
  famous use) and put the **dictionary citation at the very end** (the app hides that clause at
  display, but I need it to verify the word is real). For the ≤5% untranslatables, say it's a
  foreign untranslatable and name the source language.
- `register`: one of — neutral, formal, informal, literary, archaic, dialectal.
- `language`: always "English".
- `freePool`: false for all (I'll choose free vs premium later).

Output ONLY the JSON array — no prose, no markdown fences.

## EXCLUDE (already in the app — do not return any of these or their inflections)
abecedarian, abligurition, abreaction, absquatulate, abulia, acedia, adumbrate, afterwit, aglet, aiblins, akrasia, albedo, aliment, alpenglow, amanuensis, ambrosial, ammil, anacoluthon, anadiplosis, anagnorisis, analemma, anaphora, anfractuous, anhedonia, anomie, anon, antelucan, antimetabole, apace, apanthropy, aphelion, apophasis, apophenia, aposiopesis, apothegm, apotheosis, apricity, apsis, askance, asyndeton, ataraxia, aubade, aureole, axilla, balter, betimes, bibulous, billingsgate, bissextile, bloviate, bonhomie, borborygmus, boulevardier, boustrophedon, brattle, brio, brocken spectre, brontide, brown study, brumal, brumous, bubkes, bumbershoot, bumfuzzle, bumptious, cachinnate, caesura, caliginous, callipygian, calque, canthus, capriole, cark, cat's-paw, catachresis, cathexis, cattywampus, causerie, celadon, cento, chatoyant, chiaroscuro, chiasmus, chinoiserie, chthonic, chuffed, cinnabar, clepsydra, clerihew, clinomania, clinquant, cockalorum, cockamamie, cockcrow, codswallop, collieshangie, collop, collywobbles, colophon, coloratura, columella, comestible, comity, commonweal, compersion, compunctious, concinnous, confabulation, contrapposto, contretemps, coorie, coruscate, cosset, couthie, crapulent, craquelure, crepitate, crepuscular, crepuscule, cromulent, crwth, curglaff, curmudgeon, curvet, cwtch, cynosure, deasil, defenestration, degustation, deipnosophist, deliquesce, demesne, deshabille, desiderium, diapason, diaphanous, dimpsy, dittology, divagate, divulsion, dolor, donnybrook, drugget, dudgeon, duende, dwale, dwam, dysphemism, dépaysement, earthshine, earworm, efflorescence, effulgence, eggcorn, eidetic, ekphrasis, eldritch, eleutheromania, embiggen, ensorcell, envoi, epanalepsis, epeolatry, ephemeris, epicaricacy, epigraph, epistrophe, epithalamium, epizeuxis, erewhile, erinaceous, esculent, esemplastic, estivate, esurient, eucatastrophe, eudaimonia, eventide, exaltation, factotum, fantod, fardel, fata morgana, fernweh, ferrule, festschrift, fillip, filotimo, fipple, firn, fissiparous, flapdoodle, flibbertigibbet, flummery, flâneur, fogbow, forenoon, frangible, frenulum, frisson, frondescence, frottage, fugacious, fugue, fulgurite, fuliginous, fulminate, funambulist, fuscous, gadabout, gallus, galumph, gambado, gamboge, gambol, gardyloo, gazump, gegenschein, gemütlichkeit, geosmin, gesso, gezellig, gigglemug, gigil, girandole, glabella, glisk, glister, gloaming, gnathion, gobbledygook, gobemouche, gobsmacked, gongoozler, gormless, gouache, gowpen, graupel, griffonage, grisaille, grok, groke, guillemet, gulosity, gökotta, haar, halcyon, hallux, hangry, hebdomadal, heiligenschein, hendiadys, hesternal, hiemal, higgledy-piggledy, hikikomori, hiraeth, hoarfrost, hodophile, hornswoggle, horologe, horology, horripilation, hugger-mugger, hurkle-durkle, hypnagogic, hypnopompic, hypophora, iktsuarpok, imbroglio, impasto, incunabulum, ineffable, ineluctable, insouciant, intaglio, interregnum, interrobang, inveigle, irenic, isabelline, jammy, japanning, jolly-timbered, jouissance, jugaad, junket, kith, komorebi, kummerspeck, kvell, lacuna, lagniappe, lagom, lambent, lapidary, lechatelierite, levanter, libration, limerence, liminal, limn, lithops, litotes, logorrhea, lollop, longueur, louche, lucubrate, lucubration, ludic, luftmensch, lunula, mamihlapinatapai, mammatus, mansuetude, maquette, marcescence, martinet, matutinal, mawkish, meet-cute, meiosis, melisma, mellifluous, metanoia, milquetoast, mizzle, mondegreen, mooncalf, moonglade, mordant, mountebank, mudita, mudlark, mugwump, mukbang, mumpsimus, murmuration, mångata, naches, nacreous, nepenthe, nephology, nesh, nidor, niksen, nimbus, ninnyhammer, niveous, noctilucent, noctivagant, noesis, nudiustertian, numinous, nunchi, nychthemeron, nyctophilia, nympholepsy, obelus, obloquy, obnubilate, octothorpe, olla podrida, omerta, omnishambles, omphalos, oneiric, opalescence, opsimath, orphic, overmorrow, oxter, paduasoy, palimpsest, palinode, pandiculation, panjandrum, paramnesia, paraprosdokian, pareidolia, parhelion, paronomasia, pawky, peely-wally, pellucid, pentimento, penumbra, peradventure, perambulate, peregrinate, perforce, perihelion, periphrasis, persiflage, petrichor, pettifogger, philander, philoxenia, philtrum, phosphene, pilcrow, plangent, pococurante, poltroon, polysyndeton, popinjay, popliteal, prandial, pridian, pronk, psithurism, purl, purlicue, purlieu, qualia, querencia, quiddity, quidnunc, quietus, quockerwodger, quotidian, raconteur, raillery, ratiocination, ratoon, rebarbative, recrudescence, redolent, refection, refulgence, repoussé, resistentialism, respair, retrouvailles, reverie, rime, rodomontade, roke, saltant, samara, sangfroid, sapid, sapient, sapor, sastrugi, saturnine, saudade, scapegrace, scaramouch, schlimazel, scintilla, scripturient, scumble, scurryfunge, scuttlebutt, sehnsucht, seiche, selcouth, sempiternal, sennight, serein, serendipity, sesquipedalian, sfumato, sgraffito, sillage, sisu, sitzfleisch, skirl, skirr, smaragdine, smelfungus, smeuse, smicker, smirr, snickersnee, snirtle, snollygoster, snool, snowbroth, sobremesa, sodality, solivagant, somniloquy, sophrosyne, sough, soupçon, spindrift, spoonerism, sprezzatura, stramash, stravaig, stridulation, sublimation, supernaculum, susurration, susurrus, sybarite, syllepsis, syzygy, tantivy, taradiddle, tartle, tatterdemalion, tenebrism, tenebrous, termagant, tessitura, thenar, thixotropy, threnody, tintinnabulation, titivate, tittle, tittup, tmesis, torschlusspanik, toska, tourbillon, tragus, triboluminescence, tsundoku, twee, twitten, ubuntu, ucalegon, uhtceare, ultimo, ultracrepidarian, umbra, umbrage, utepils, uxorious, valetudinarian, vatic, velleity, verdigris, verglas, verklempt, vernation, vertiginous, vespertine, viand, virga, virgule, volplane, vomitory, vorfreude, wabbit, wabi-sabi, wamble, wassail, wastrel, welkin, weltschmerz, whiffler, whilom, widdershins, williwaw, willy-nilly, winsome, wlonk, woolgathering, yclept, yestreen, zawn, zenzizenzizenzic, zephyr, zeugma, zhuzh, zodiacal light, zugzwang, zwer

---

**When done:** save the result as `gems_round12.json` (a file on disk — UTF-8, NOT pasted into
chat). Tell me when it's there and I'll dedup against the 574, validate, bump the DB version, and
import.
