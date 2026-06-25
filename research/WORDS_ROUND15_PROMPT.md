# Deep-research prompt — 100 NEW "wow" words (round 15)

> Paste everything below into a deep-research tool. Save the result to disk as `gems_round15.json`
> (UTF-8). None of the 874 words listed at the bottom may appear — they are already in the app.

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

## NOTE — the easy words are taken
874 words are already in (see EXCLUDE). The obvious untranslatables and the famous rare words are
mostly used. Dig deeper: regional/dialect English (Scots, Northern, West Country, Irish, Welsh-
English, Caribbean, Indian English), archaic-but-gorgeous revivals, and precise feeling-words from
other languages that are genuine dictionary headwords in English. Quality over fame.

## HARD RULES (break any → rejected)
1. **Real English headword** in at least ONE of: Oxford English Dictionary, Merriam-Webster, or
   Collins. Name which at the END of `etymology`. Naturalized loanwords that became English
   headwords are fine (schadenfreude, frisson, hygge).
2. **Mix:** ~95% genuine English-dictionary headwords; ≤5% iconic foreign "untranslatable"
   FEELING-words (sehnsucht-type), only world-famous evocative ones.
3. **No duplicates.** None of the 874 words in the EXCLUDE list below, and no simple inflections
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

## EXCLUDE — already in the app, do NOT return any of these or their inflections (874 words)
abecedarian, abligurition, abreaction, absquatulate, abulia, acedia, adumbrate, afterclap, afterglow, afterwit, aglet, agog, aiblins, akrasia, albedo, albescent, aliment, alpenglow, amanuensis, amaranthine, ambrosial, ammil, anacoluthon, anadiplosis, anagnorisis, analemma, anamnesis, anaphora, anfractuous, anhedonia, anomie, anon, antelucan, antimetabole, apace, apanthropy, aphelion, apophasis, apophenia, aposiopesis, apothegm, apotheosis, apricate, apricity, apsis, ardor, argent, argy-bargy, askance, asyndeton, ataraxia, attar, aubade, aureate, aureole, aurora, aurorean, axilla, balderdash, balm, balter, beatitude, beck, bereft, besotted, betimes, bibelot, bibulous, billingsgate, billow, bissextile, blate, blithesome, bloviate, bonhomie, borborygmus, bosky, boulevardier, boustrophedon, bower, brae, brattle, brine, brio, brocken spectre, brontide, brool, brouhaha, brown study, brumal, brume, brumous, bubkes, bumbershoot, bumfuzzle, bumptious, burble, cachinnate, caesura, caliginous, callipygian, calque, candent, candescent, canoodle, canorous, cantankerous, canthus, canty, caprice, capriole, cark, cat's-paw, catachresis, cathexis, cattywampus, causerie, cavort, celadon, cento, cerulean, chatoyant, chiaroscuro, chiasmus, chinoiserie, chirm, chthonic, chuffed, churr, cinnabar, clement, clepsydra, clerihew, clinomania, clinquant, clough, cockalorum, cockamamie, cockcrow, cockshut, codswallop, collieshangie, collop, collywobbles, colophon, coloratura, columella, combe, comestible, comity, commonweal, compersion, compunctious, concinnous, confabulation, contrapposto, contretemps, contrition, coorie, coquette, corposant, corrie, coruscate, cosset, couthie, crapulent, craquelure, crepitate, crepuscular, crepuscule, crestfallen, crinkum-crankum, cromulent, croodle, crotchety, crwth, curglaff, curmudgeon, curvet, cwm, cwtch, cynosure, dale, dappled, dayspring, deasil, defenestration, degustation, deipnosophist, delectation, deliquesce, dell, demesne, dern, deshabille, desiderate, desiderium, desuetude, dewfall, diapason, diaphanous, dillydally, dimpsy, dingle, dirge, discombobulate, disconsolate, disquiet, dittology, divagate, divulsion, doldrums, dolor, dolorifuge, donnybrook, douceur, dowie, dreich, drookit, drugget, drumly, dudgeon, duende, dulcet, duskish, dwale, dwam, dysphemism, dépaysement, earthshine, earworm, ebullient, eddy, effervescent, efflorescence, effulgence, eggcorn, eidetic, ekphrasis, elation, eldritch, eleutheromania, elflock, elysian, embiggen, empyrean, enchantment, ennui, ensorcell, envoi, epanalepsis, epeolatry, ephemeral, ephemeris, epicaricacy, epigraph, epiphany, epistrophe, epithalamium, epizeuxis, equanimity, erewhile, erinaceous, erstwhile, esculent, esemplastic, estival, estivate, esurient, eucatastrophe, eudaimonia, evanescent, evenfall, eventide, exaltation, factotum, fankle, fantod, fardel, farrago, fata morgana, felicity, fell, fen, ferly, ferntickle, fernweh, ferrule, festschrift, fey, fillip, filotimo, fipple, firmament, firn, fissiparous, flammeous, flapdoodle, flibbertigibbet, flummery, flummox, flâneur, fogbow, folderol, foofaraw, forenoon, forlorn hope, forpine, foxfire, frabjous, frangible, frenulum, freshet, fret, frippery, frisson, frondescence, frottage, fugacious, fugue, fulgent, fulgurant, fulgurite, fuliginous, fulminate, funambulist, fuscous, gadabout, gallimaufry, gallus, galumph, gambado, gamboge, gambol, gardyloo, gazump, gegenschein, gelid, gemütlichkeit, gentilesse, geosmin, gesso, gewgaw, gezellig, gigglemug, gigil, girandole, glabella, glade, gladsome, glaucous, glen, glimmer, glisk, glister, gloam, gloaming, gloriole, gloze, gnathion, gobbledygook, gobemouche, gobsmacked, gongoozler, gormless, gossamer, gouache, gowk, gowpen, gramarye, graupel, griffonage, grisaille, grok, groke, gubbins, guddle, guillemet, gulosity, gökotta, haar, halcyon, halidom, hallux, hangry, heartsease, heartsore, hebdomadal, heiligenschein, hendiadys, hesternal, hibernal, hiemal, higgledy-piggledy, hikikomori, hiraeth, hoarfrost, hodiernal, hodophile, holt, homefelt, hornswoggle, horologe, horology, horripilation, hugger-mugger, hullabaloo, hurkle-durkle, hwyl, hygge, hypnagogic, hypnopompic, hypophora, ignis fatuus, iktsuarpok, imbroglio, impasto, inamorata, incalescence, incunabulum, ineffable, ineluctable, ingenue, inquietude, insouciant, intaglio, interregnum, interrobang, inveigle, irenic, iridescent, isabelline, jammy, japanning, jocund, joie de vivre, jolly-timbered, jouissance, jugaad, junket, kairos, keen, kerfuffle, kith, knell, komorebi, kummerspeck, kvell, lachrymose, lacuna, lagniappe, lagom, lambent, languor, lapidary, lassitude, lea, lechatelierite, levanter, libration, lichgate, lightsome, lilt, limerence, liminal, limn, limpid, linn, lithops, litotes, logorrhea, lollop, lollygag, longueur, louche, lovelorn, lown, lucency, lucent, lucubrate, lucubration, ludic, luftmensch, lull, lunula, lustrous, machair, mackerel sky, malarkey, mamihlapinatapai, mammatus, mansuetude, maquette, marcescence, martinet, matutinal, maudlin, mauther, mauvais quart d'heure, mawkish, meet-cute, megrim, meiosis, melisma, mellifluous, mere, metanoia, micant, milquetoast, mirligoes, mirth, mizzle, mollitude, mollycoddle, mondegreen, mono no aware, moonbow, mooncalf, moonglade, mordant, mountebank, mudita, mudlark, mugwump, mukbang, mulligrubs, mumpsimus, murmuration, murmurous, mångata, naches, nacre, nacreous, nemorous, nepenthe, nephology, nesh, nidor, niksen, nimbus, nincompoop, ninnyhammer, nitid, niveous, noctilucent, noctilucous, noctivagant, noesis, nonpareil, nubilous, nudiustertian, numinous, nunchi, nychthemeron, nyctophilia, nympholepsy, obelus, obloquy, obnubilate, octothorpe, olla podrida, omerta, omnishambles, omphalos, oneiric, oorie, opalescence, opsimath, orphic, overmorrow, owl-light, oxter, paduasoy, palimpsest, palinode, pandiculation, panjandrum, paragon, paramnesia, paramour, paraprosdokian, pareidolia, parhelion, paronomasia, pawky, peely-wally, pellucid, pensive, pentimento, penumbra, peradventure, perambulate, percipience, peregrinate, perforce, perihelion, periphrasis, persiflage, persnickety, petrichor, pettifogger, philander, philoxenia, philtrum, phosphene, pilcrow, plaintive, plangent, plash, plenilune, plenitude, pococurante, poltroon, polysyndeton, popinjay, popliteal, poppycock, posy, prandial, pridian, pronk, psithurism, purl, purlicue, purlieu, qualia, querencia, quiddity, quidnunc, quietude, quietus, quockerwodger, quotidian, raconteur, ragamuffin, raillery, rapscallion, ratiocination, ratoon, rebarbative, recrudescence, redolent, refection, refulgence, relucent, repine, repose, repoussé, resistentialism, respair, restive, retrouvailles, reverie, rhapsodic, rigmarole, rill, rime, rivulet, rodomontade, roke, roseate, rubescent, rueful, runnel, ruth, rutilant, saltant, samara, sangfroid, sapid, sapient, sapor, sastrugi, satori, saturnine, saudade, scapegrace, scaramouch, schlimazel, scintilla, scintillant, scripturient, scumble, scurryfunge, scuttlebutt, sehnsucht, seiche, selcouth, sempiternal, sennight, serein, serendipity, serotine, sesquipedalian, sfumato, sgraffito, shaw, sillage, sisu, sitzfleisch, skedaddle, skerry, skirl, skirr, smaragd, smaragdine, smeddum, smelfungus, smeuse, smicker, smirr, snell, snickersnee, snirtle, snod, snollygoster, snool, snowbroth, sobremesa, sodality, sojourn, solivagant, somniloquy, somnolent, sophrosyne, sough, soupçon, spate, spindrift, spinney, splendent, spoonerism, sprezzatura, spume, starshine, stoor, stooshie, stramash, stravaig, stridulation, subfusc, sublimation, supernaculum, supernal, susurrant, susurration, susurrus, swain, swale, swither, swoon, sybarite, syllepsis, sylvan, syzygy, tantivy, taradiddle, tarn, tartle, tatterdemalion, teen, tendresse, tenebrism, tenebrous, termagant, tessitura, thenar, thixotropy, thole, thrall, threnody, thrum, thunderhead, tintinnabulation, titivate, tittle, tittup, tmesis, tor, torschlusspanik, toska, tourbillon, tragus, tremulous, triboluminescence, triste, tristesse, tristful, tsundoku, twee, twitten, ubuntu, ucalegon, uhtceare, ultimo, ultracrepidarian, umbra, umbrage, umbrageous, umbratile, umbriferous, utepils, uxorious, vagary, vale, valetudinarian, vatic, velleity, verdant, verdigris, verdurous, verglas, verklempt, vermeil, vernal, vernation, vertiginous, vesperal, vespertide, vespertine, viand, virescent, virga, virgule, viridian, voe, volplane, vomitory, vorfreude, wabbit, wabi-sabi, wae, waft, wamble, wanderlust, wanhope, warble, wassail, wastrel, weald, weet, welkin, weltschmerz, wend, whicker, whiffler, whigmaleerie, whilom, whimsy, whippersnapper, widdershins, will-o'-the-wisp, williwaw, willy-nilly, winsome, wistful, wlonk, woebegone, wold, wonderment, woolgathering, wuthering, yclept, yearnful, yen, yestreen, zawn, zenzizenzizenzic, zephyr, zeugma, zhuzh, zodiacal light, zugzwang, zwer

---

**When done:** save as `gems_round15.json` (a real file on disk, UTF-8 — NOT pasted into chat) and
tell me where it is.
