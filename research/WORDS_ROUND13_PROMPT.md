# Deep-research prompt — 100 NEW "wow" words (round 13)

> Paste everything below into a deep-research tool. Save the result to disk as `gems_round13.json`
> (UTF-8). Do NOT exclude any of the 674 words listed at the bottom — they are already in the app.

---

You are a lexicographer curating words for **Verbum**, an iOS app about **beautiful, rare English
words**. Promise: *"collect the words for feelings you couldn't name."* Users swipe a TikTok-style
feed of gorgeous words, **claim** the ones that move them into a personal lexicon, and write why
each is theirs. So the words must be **emotionally resonant and delightful**, not dry trivia.

Give me **100 NEW "wow" words** — rare, beautiful, surprising words that make an educated native
speaker think *"I can't believe there's a word for that."*

## THE BAR — what "wow" means here
Strongly prefer words that are at least one of:
- a precise name for a **feeling / inner state / human moment** everyone knows but can't name
  (longing, awe, tenderness, restlessness, bittersweetness, contentment);
- **sensory / atmospheric** — light, weather, sound, scent, the textures of the world
  (think *petrichor, gloaming, susurrus, chatoyant*);
- **charmingly strange or playful** to say (think *collywobbles, snollygoster*);
- **evocative and poetic** — the kind of word you'd screenshot.

If a literate adult wouldn't be *delighted* to learn it, cut it.

## ⚠️ AVOID (the catalogue is already over-full of these)
No dry/technical "curiosity" words — they dilute the emotional feel:
- rhetoric/grammar terms (chiasmus, zeugma, litotes);
- typography/punctuation (pilcrow, interrobang, octothorpe);
- anatomy (hallux, oxter, philtrum);
- art/craft-technique jargon (sfumato, impasto, gesso);
- pure science/math/astronomy jargon (apsis, ephemeris, thixotropy).
Lean **emotional, sensory, poetic, human** instead.

## HARD RULES (break any → rejected)
1. **Real English headword** in at least ONE of: Oxford English Dictionary, Merriam-Webster, or
   Collins. Name which at the END of `etymology`. Naturalized loanwords that became English
   headwords are fine (schadenfreude, frisson, hygge).
2. **Mix:** ~95% genuine English-dictionary headwords; ≤5% iconic foreign "untranslatable"
   FEELING-words (sehnsucht-type), only world-famous evocative ones.
3. **No duplicates.** None of the 674 words in the EXCLUDE list below, and no simple inflections
   of them (plural / -ing / -ly count as duplicates).
4. **Every word needs a natural example sentence** that shows the meaning in use.
5. **English/Latin script only**, UTF-8.
6. **Accurate definitions.** No invented/folk-etymology words, no blog-coined neologisms (exclude
   coinages like sonder/anemoia unless they entered a real dictionary).

## OUTPUT FORMAT
Return ONE JSON array of 100 objects, each EXACTLY these keys:

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
- `partOfSpeech`: noun / verb / adjective / adverb / interjection / phrase.
- `synonyms`, `antonyms`, `domainTags`: comma-separated strings ("" if none).
- `category`: ONE of — Emotions, Nature, Mind, People, Society, Time, Language, Art, Movement,
  General. (Bias toward Emotions / Nature / Mind.)
- `etymology`: interesting origin trivia, with the dictionary citation at the very END (the app
  hides that clause at display, but I need it to verify the word is real).
- `register`: neutral / formal / informal / literary / archaic / dialectal.
- `language`: always "English".
- `freePool`: false for all.

Output ONLY the JSON array — no prose, no markdown fences.

## EXCLUDE — already in the app, do NOT return any of these or their inflections (674 words)
abecedarian, abligurition, abreaction, absquatulate, abulia, acedia, adumbrate, afterglow, afterwit, aglet, agog, aiblins, akrasia, albedo, aliment, alpenglow, amanuensis, ambrosial, ammil, anacoluthon, anadiplosis, anagnorisis, analemma, anaphora, anfractuous, anhedonia, anomie, anon, antelucan, antimetabole, apace, apanthropy, aphelion, apophasis, apophenia, aposiopesis, apothegm, apotheosis, apricity, apsis, askance, asyndeton, ataraxia, attar, aubade, aureole, axilla, balm, balter, beatitude, beck, bereft, besotted, betimes, bibulous, billingsgate, bissextile, blithesome, bloviate, bonhomie, borborygmus, boulevardier, boustrophedon, bower, brae, brattle, brio, brocken spectre, brontide, brouhaha, brown study, brumal, brume, brumous, bubkes, bumbershoot, bumfuzzle, bumptious, burble, cachinnate, caesura, caliginous, callipygian, calque, canthus, capriole, cark, cat's-paw, catachresis, cathexis, cattywampus, causerie, celadon, cento, cerulean, chatoyant, chiaroscuro, chiasmus, chinoiserie, chthonic, chuffed, cinnabar, clepsydra, clerihew, clinomania, clinquant, clough, cockalorum, cockamamie, cockcrow, cockshut, codswallop, collieshangie, collop, collywobbles, colophon, coloratura, columella, combe, comestible, comity, commonweal, compersion, compunctious, concinnous, confabulation, contrapposto, contretemps, contrition, coorie, corrie, coruscate, cosset, couthie, crapulent, craquelure, crepitate, crepuscular, crepuscule, crestfallen, crinkum-crankum, cromulent, crwth, curglaff, curmudgeon, curvet, cwm, cwtch, cynosure, dayspring, deasil, defenestration, degustation, deipnosophist, delectation, deliquesce, demesne, deshabille, desiderium, dewfall, diapason, diaphanous, dimpsy, dingle, dirge, disconsolate, dittology, divagate, divulsion, doldrums, dolor, donnybrook, drugget, dudgeon, duende, dwale, dwam, dysphemism, dépaysement, earthshine, earworm, ebullient, eddy, efflorescence, effulgence, eggcorn, eidetic, ekphrasis, eldritch, eleutheromania, embiggen, empyrean, ennui, ensorcell, envoi, epanalepsis, epeolatry, ephemeris, epicaricacy, epigraph, epistrophe, epithalamium, epizeuxis, equanimity, erewhile, erinaceous, esculent, esemplastic, estivate, esurient, eucatastrophe, eudaimonia, evenfall, eventide, exaltation, factotum, fantod, fardel, farrago, fata morgana, fell, fernweh, ferrule, festschrift, fillip, filotimo, fipple, firmament, firn, fissiparous, flapdoodle, flibbertigibbet, flummery, flâneur, fogbow, forenoon, forlorn hope, foxfire, frangible, frenulum, freshet, frisson, frondescence, frottage, fugacious, fugue, fulgurite, fuliginous, fulminate, funambulist, fuscous, gadabout, gallimaufry, gallus, galumph, gambado, gamboge, gambol, gardyloo, gazump, gegenschein, gemütlichkeit, geosmin, gesso, gezellig, gigglemug, gigil, girandole, glabella, gladsome, glen, glisk, glister, gloam, gloaming, gnathion, gobbledygook, gobemouche, gobsmacked, gongoozler, gormless, gossamer, gouache, gowpen, graupel, griffonage, grisaille, grok, groke, gubbins, guillemet, gulosity, gökotta, haar, halcyon, hallux, hangry, heartsore, hebdomadal, heiligenschein, hendiadys, hesternal, hiemal, higgledy-piggledy, hikikomori, hiraeth, hoarfrost, hodophile, holt, hornswoggle, horologe, horology, horripilation, hugger-mugger, hurkle-durkle, hygge, hypnagogic, hypnopompic, hypophora, iktsuarpok, imbroglio, impasto, incunabulum, ineffable, ineluctable, inquietude, insouciant, intaglio, interregnum, interrobang, inveigle, irenic, isabelline, jammy, japanning, jocund, jolly-timbered, jouissance, jugaad, junket, keen, kerfuffle, kith, knell, komorebi, kummerspeck, kvell, lachrymose, lacuna, lagniappe, lagom, lambent, languor, lapidary, lassitude, lea, lechatelierite, levanter, libration, lightsome, lilt, limerence, liminal, limn, linn, lithops, litotes, logorrhea, lollop, longueur, louche, lovelorn, lucubrate, lucubration, ludic, luftmensch, lull, lunula, machair, mackerel sky, mamihlapinatapai, mammatus, mansuetude, maquette, marcescence, martinet, matutinal, maudlin, mauvais quart d'heure, mawkish, meet-cute, megrim, meiosis, melisma, mellifluous, mere, metanoia, milquetoast, mizzle, mondegreen, moonbow, mooncalf, moonglade, mordant, mountebank, mudita, mudlark, mugwump, mukbang, mulligrubs, mumpsimus, murmuration, mångata, naches, nacreous, nepenthe, nephology, nesh, nidor, niksen, nimbus, ninnyhammer, niveous, noctilucent, noctivagant, noesis, nudiustertian, numinous, nunchi, nychthemeron, nyctophilia, nympholepsy, obelus, obloquy, obnubilate, octothorpe, olla podrida, omerta, omnishambles, omphalos, oneiric, opalescence, opsimath, orphic, overmorrow, owl-light, oxter, paduasoy, palimpsest, palinode, pandiculation, panjandrum, paramnesia, paraprosdokian, pareidolia, parhelion, paronomasia, pawky, peely-wally, pellucid, pensive, pentimento, penumbra, peradventure, perambulate, peregrinate, perforce, perihelion, periphrasis, persiflage, petrichor, pettifogger, philander, philoxenia, philtrum, phosphene, pilcrow, plaintive, plangent, pococurante, poltroon, polysyndeton, popinjay, popliteal, prandial, pridian, pronk, psithurism, purl, purlicue, purlieu, qualia, querencia, quiddity, quidnunc, quietus, quockerwodger, quotidian, raconteur, raillery, ratiocination, ratoon, rebarbative, recrudescence, redolent, refection, refulgence, repine, repoussé, resistentialism, respair, retrouvailles, reverie, rhapsodic, rill, rime, rodomontade, roke, rueful, runnel, saltant, samara, sangfroid, sapid, sapient, sapor, sastrugi, saturnine, saudade, scapegrace, scaramouch, schlimazel, scintilla, scripturient, scumble, scurryfunge, scuttlebutt, sehnsucht, seiche, selcouth, sempiternal, sennight, serein, serendipity, sesquipedalian, sfumato, sgraffito, sillage, sisu, sitzfleisch, skerry, skirl, skirr, smaragdine, smelfungus, smeuse, smicker, smirr, snickersnee, snirtle, snollygoster, snool, snowbroth, sobremesa, sodality, solivagant, somniloquy, sophrosyne, sough, soupçon, spate, spindrift, spinney, spoonerism, sprezzatura, stramash, stravaig, stridulation, sublimation, supernaculum, susurration, susurrus, swoon, sybarite, syllepsis, syzygy, tantivy, taradiddle, tarn, tartle, tatterdemalion, tenebrism, tenebrous, termagant, tessitura, thenar, thixotropy, threnody, thrum, thunderhead, tintinnabulation, titivate, tittle, tittup, tmesis, tor, torschlusspanik, toska, tourbillon, tragus, triboluminescence, tristful, tsundoku, twee, twitten, ubuntu, ucalegon, uhtceare, ultimo, ultracrepidarian, umbra, umbrage, utepils, uxorious, vale, valetudinarian, vatic, velleity, verdigris, verglas, verklempt, vernation, vertiginous, vespertine, viand, virga, virgule, voe, volplane, vomitory, vorfreude, wabbit, wabi-sabi, waft, wamble, warble, wassail, wastrel, welkin, weltschmerz, whiffler, whigmaleerie, whilom, widdershins, williwaw, willy-nilly, winsome, wistful, wlonk, woebegone, wold, wonderment, woolgathering, wuthering, yclept, yestreen, zawn, zenzizenzizenzic, zephyr, zeugma, zhuzh, zodiacal light, zugzwang, zwer

---

**When done:** save as `gems_round13.json` (a real file on disk, UTF-8 — NOT pasted into chat) and
tell me where it is.
