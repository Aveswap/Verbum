# Verbum — Project Handoff

**Last updated:** 2026-06-27
**Branch:** `main`
**Status:** Feature-complete, pre-release. Never compiled by the author (see Constraint below) —
static-reviewed line-by-line multiple times, including a full senior-level walkthrough of every
screen on 2026-06-27. Not yet submitted to the App Store.

> Read this top-to-bottom before touching the code. It supersedes every other doc in the repo.

---

## 1. What Verbum is

A SwiftUI iOS app: a TikTok-style vertical swipe feed of rare, beautiful English words (974 and
growing), each a genuine OED/Merriam-Webster/Collins headword with IPA, definition, example
sentence, and etymology. Positioning: *"collect the words for feelings you couldn't name."*

Core loop: swipe the feed → tap a word you love → **claim** it into your personal **Lexicon** (with
an optional "why this word is mine" note) → the app resurfaces *that exact word* in a daily
notification before you forget it → tapping the notification opens *that* word, ready to save/like/
share. Optional **Practice** (opt-in games + timed challenges) turns remembering into light
competition, feeding a quarterly points leaderboard.

Monetization: 50 words free (hand-curated, see §4), the rest + Practice behind
monthly/yearly/lifetime StoreKit 2 subscriptions.

---

## 2. Constraint that shapes everything here

**The author has Command-Line-Tools only — no Xcode/iOS SDK, cannot compile or run the app.**
Every change in this repo (including everything described below) is **static-reviewed**: brace
balance, dangling-reference greps, and careful manual reasoning about Swift 6 actor isolation — not
an actual `swiftc`/Xcode build. Treat this repo as *believed-correct, unverified-on-device*.

**Before you do anything else:** open it in real Xcode, run `xcodegen generate` if you've touched
`project.yml`, and build. Fix whatever the compiler says before trusting any of this document's
"done" claims.

---

## 3. Architecture

- **iOS 16.0+, SwiftUI, Swift 6, `SWIFT_STRICT_CONCURRENCY: complete`.** Dark mode only.
- **XcodeGen** — `project.yml` is the source of truth; `Verbum.xcodeproj` is generated
  (`xcodegen generate`) and never hand-edited. Three targets:
  - `Verbum` (app) — `TARGETED_DEVICE_FAMILY: 1` (iPhone-only, deliberate — see §7).
  - `VerbumWidgets` (app-extension) — hosts the Rush-challenge Live Activity. Embedded in the app
    via `dependencies: [{ target: VerbumWidgets, embed: true }]`.
  - `VerbumTests` (unit tests) — `StreakEngineTests`, `CloudKitMergeTests`.
- **GRDB/SQLite** — the word catalogue only. `Verbum/Resources/words_v2.db` is bundled and opened
  **read-only, in place** (`WordDatabase.openBundledReadOnly()`); no copy, no migration, no OTA
  download path — that entire subsystem was removed 2026-06-27 as dead code (see §9).
- **All user state** (claimed words, notes, streak, settings, reviews) lives in `UserProfile`
  (`UserDefaults`, JSON-encoded) via `UserProfileStore`, optionally synced through CloudKit
  (currently stubbed — §5).

---

## 4. The word catalogue

- **974 English words**, `bundledDBVersion = 43`. Every content round is logged as a versioned
  comment directly above `bundledDBVersion` in `WordDatabase.swift` — read that block for the full
  history (rounds 1–15, prunes, the pivot away from multi-language/leveled content, etc.).
- **English-only at runtime.** `.lproj` folders (en/de/uk) exist for **UI string** localization
  only — that's a separate, still-live system (`gen_localizations.py`, `_ui_strings.json`); don't
  confuse it with the (now-deleted) multi-language *word* pipeline.
- **Pipeline** (scripts/): `import_gems.py` reads every `*.json` in `word_batches_gems/`, dedupes,
  imports into `words_v2.db`, copies to `Verbum/Resources/`. Then `validate_content.py`, then
  `export_fallback_json.py` (regenerates `words.json`, the fallback source if the DB fails to open).
  Bump `bundledDBVersion` after every import. Full write-up: `docs/BACKEND.md` is unrelated (that's
  the dormant cross-user backend) — there's no separate pipeline doc anymore; this section + the
  scripts' own docstrings are the source of truth now.
- **To get the next 100 words:** generate a prompt with `research/WORDS_ROUND{N}_PROMPT.md` as a
  template — it EXCLUDEs every word currently in the DB (pull fresh via `sqlite3` `SELECT text FROM
  words`), asks for dictionary-verified, emotionally-resonant words, deep-research-tool-ready. Drop
  the result JSON into `scripts/word_batches_gems/gems_round{N}.json` and run the pipeline above.
- **`WordAccess.curatedFront`** (added 2026-06-26): a **hand-picked, ordered** list of the best ~10
  words (petrichor, hiraeth, gloaming, saudade, susurrus, hygge, komorebi, mellifluous, ineffable,
  serendipity) that are forced into the free pool and shown **first, unshuffled** — the free feed's
  opening is the conversion moment, so it's curated, not randomized (council decision, see the
  earlier chat history if you need the reasoning). The free feed only shuffles *already-seen* words;
  unseen ones stay in curated order (`WordFeedViewModel.unseenFirst(_:preserveUnseenOrder:)`).
  **TODO left for the product owner:** extend `curatedFront` toward ~50 to fully curate the free
  sample, with a second wave of strong words positioned near the end (peak-end effect right before
  the paywall).

---

## 5. Intentionally-stubbed services — do not "fix" without reading this

`CloudKitSyncManager`, `AuthService` (Sign in with Apple), `GameCenterService` in `Core/Data/` are
**no-op stubs**, each prefixed with a `⚠️ LOCAL-DEV STUB` comment. Real implementations are
preserved at `_LocalDev-Disabled/*.original`. They're gated by:

- `AppInfo.isSignInConfigured = false` → hides the Account section entirely (no dead Sign-in button
  a reviewer could tap into "disabled in local dev").
- `AppInfo.isGameCenterConfigured = false` → hides Game Center leaderboard/friends cards.

**To restore:** replace the stub file with its `.original`, re-add the entitlement in
`Verbum/Verbum.entitlements`, flip the `AppInfo` flag, provision the capability in the Apple
Developer portal / App Store Connect. This is a deliberate, correctly-gated decision — not
half-finished work. Ship without them first if you want; nothing breaks.

**Separately dormant:** a cross-user backend (GameCenter leaderboards + CloudKit public-DB "likes")
behind the `VERBUM_BACKEND` compile flag (off). `Core/Data/Backend.swift`,
`LeaderboardService.swift`, `PublicLikesService.swift`. Provisioning steps: `docs/BACKEND.md`. The
like-count UI (`WordFeedView`, `WordDetailView`) already only ever shows a REAL number from this
service — **never a fabricated placeholder** (that was ripped out 2026-06-26 as an App Store
1.1.6/2.3.1 rejection risk; see commit `de5c6b7`).

---

## 6. What changed in the 2026-06-27 session (most recent work)

1. **Notification word rotation, fixed.** The daily word notification used `repeats: true` with
   content baked in once — iOS re-fires the *identical* text forever, and since SwiftUI's root
   `.onAppear` doesn't refire on mere foregrounding, most users saw the same word for days. Now
   `NotificationManager.reschedule` pre-schedules a **rolling window of non-repeating notifications**
   (up to 7 days, sized to stay under Apple's 64-pending cap), refreshed at most once/day from
   `VerbumApp`'s `onAppear` *and* every `scenePhase == .active`. Personal (claimed) words rotate by
   sliding the window one word further per day (`(day + slot) % pool.count`); the word-of-the-day
   fallback (nothing claimed yet) already varied by date via `DailyWords.forToday(now:)`, now
   actually exercised per-day instead of frozen. `reminderWords(limit:)` call sites bumped from
   `count` to `50` so there's real material to rotate through.
   **Deep-link-opens-the-tapped-word was verified already-correct, untouched:** the notification's
   `userInfo["wordId"]` is the exact word shown; tapping posts `.openWord`; `WordFeedView` presents
   `WordDetailView(word:)` as a sheet — same word, Save/Like/Share all present in the toolbar.
2. **Dead code purge (~2,000 lines / 68 files).** Legacy multi-language/1000-word CDN pipeline
   (`generate_1000_words.py`, `build_de_catalog.py`, `insert_uk_*.py`, `word_batches/`,
   `word_batches_de/`, `WORDS_DB_PIPELINE.md` — all described an abandoned architecture); the
   obsolete home-screen "Word of the Day" widget concept in `_LocalDev-Disabled/VerbumWidget/`
   (superseded by the Live Activity in `VerbumWidgets/`); `DatabaseDownloadManager.swift` (zero
   callers — the OTA-download path was never wired up and the app has shipped bundled-only since);
   `WordDatabase`'s entire migrations/import/writable-copy subsystem (`runMigrations`,
   `createSchema`, `importWords`, `databaseURL`, `bundledVersionKey` — the class's own comments
   already said "no copy, no migration, nothing to run at open time"); stale root-level audit/prompt
   docs superseded by `research/`. See commit history for the full list.
3. **Two real bugs found and fixed** during a full senior-level screen-by-screen review:
   - `QuizViewModel.nextQuestion()`: with a pool of exactly 4 words (the guard's minimum) and 5
     fixed questions, the 5th pick had no unused word left and the quiz silently ended on question 4
     — but the results screen still read "Score: X / 5" (wrong denominator). Fixed with the same
     resilient `pickWord()` pattern already used by `FillGapView`/`GuessWordView`/`SynonymsView`
     (allow a repeat rather than end early, never repeating the just-asked word).
   - `GuessWordView`: the "Next" button was still conditionally rendered (`if selectedAnswer != nil`),
     causing the exact "layout jitter" the other three practice games explicitly fixed (button pops
     in and pushes content). Brought in line: always-rendered, opacity-toggled.
4. **Curated free-pool "trailer"** (`WordAccess.curatedFront`, §4) and **smart free-feed ordering**
   (`WordFeedViewModel`, commit `2427416` — free feed previously served a frozen freq-rank sequence,
   now FSRS-due → unseen(curated/shuffled) → seen(shuffled), matching the Pro feed's logic).
5. **App Store compliance pass** (commit `de5c6b7`, from a formal external audit — see
   `research/RELEASE_AUDIT_PROMPT.md` if you want to re-run it): removed the fabricated like count,
   added `VerbumWidgets/PrivacyInfo.xcprivacy` (each binary needs its own), iPhone-only device
   family, expanded the paywall's auto-renewal disclosure to the full required legal text. Verified
   (no code needed): stubs fully hidden, deep-link UUID validation, required Info.plist keys present.
6. **`docs/APP_STORE_LISTING.md`** — ready-to-paste App Store Connect copy (name/subtitle/keywords/
   description/what's-new), App Privacy answers ("Data Not Collected" — the shipping build is fully
   local), Age Rating answers (4+), App Review notes (justifies the Live Activity's ActivityKit use).

Earlier session history (redesign stages, Dynamic Island build-out, word rounds 12–15, the
Profile+Settings merge, etc.) is in `git log` — commit messages are detailed and dated; read them
rather than trusting a summary here to stay current.

---

## 7. Release blockers — only the author/owner can do these

Nothing below is a code problem; all are Apple-account/Xcode/hosting actions:

1. **App Icon is empty** (`AppIcon.appiconset` has a `Contents.json`, zero PNGs). Hard blocker —
   Apple rejects instantly without one.
2. **Build on a real device in real Xcode.** First actual compile of a large amount of this work,
   especially the widget extension / Live Activity — go in expecting to fix things.
3. **`DEVELOPMENT_TEAM` is empty** in `project.yml` for all three targets — set your Team ID,
   sign `VerbumWidgets` too (same team as the app).
4. **Host `docs/privacy.html`** so `https://verbum.app/privacy` (referenced from the paywall and the
   App Store listing) actually resolves — currently 404. GitHub Pages is the fastest path.
5. **Set the real `AppInfo.appStoreID`** once the App Store Connect record exists (unlocks Rate/
   Share/Invite — they're correctly hidden while it's the placeholder `"0000000000"`).
6. **App Store Connect setup:** create `pro_monthly`/`pro_yearly`/`pro_lifetime` IAP products
   (currently only in the local `Verbum.storekit` test config), screenshots (iPhone only — device
   family was deliberately narrowed, §6.item5), the App Privacy nutrition label (paste from
   `docs/APP_STORE_LISTING.md`), the Age Rating questionnaire (paste from the same doc), License
   Agreement → Standard Apple EULA.
7. **iOS 26 SDK / current Xcode** — Apple requires it for submissions from ~April 2026; make sure
   your toolchain is current before archiving.
8. **Revoke/rotate the GitHub PAT** sitting in plaintext in `.git/config`'s remote URL (confirmed
   never committed to the repo itself, but rotate it anyway — it's visible in `git remote -v`).
9. **TestFlight first.** Given the compile-blind history above, do not go straight to public release.
10. Decide on §5's stubbed services (ship without Sign in with Apple/CloudKit/Game Center first, or
    provision and restore them) — either is fine, just be deliberate.

---

## 8. Quick command reference

```bash
# Regenerate the Xcode project after touching project.yml or adding/removing files
xcodegen generate

# Import a new round of words (after dropping gems_round{N}.json into scripts/word_batches_gems/)
cd scripts
python3 import_gems.py            # imports + copies DB to Verbum/Resources/
python3 validate_content.py       # should print errors=0
python3 export_fallback_json.py   # regenerates words.json fallback
# then bump WordDatabase.bundledDBVersion and add a changelog comment line above it

# Check current word count
sqlite3 Verbum/Resources/words_v2.db "select language, count(*) from words group by language;"

# Static sanity check after any edit (since real compiles aren't possible here)
# — brace balance:
for f in <changed files>; do
  o=$(tr -cd '{' < "$f" | wc -c); c=$(tr -cd '}' < "$f" | wc -c)
  [ "$o" -eq "$c" ] && echo OK || echo "MISMATCH: $f"
done
```

---

## 9. Where things live (map, not exhaustive — read the code)

- `Verbum/App/` — `VerbumApp` (entry point, notification rescheduling, deep links), `AppCoordinator`
  (onboarding vs. feed routing).
- `Verbum/Core/Data/` — `WordRepository`/`WordDatabase`/`WordAccess` (catalogue + free-pool logic),
  `UserProfileStore`/`UserProfile` (all user state + its CloudKit merge), `StreakEngine`/`FSRS`
  (pure, unit-tested), `SubscriptionManager` (StoreKit 2), the stubbed services (§5), `DailyWords`.
- `Verbum/Core/LiveActivity/` + `VerbumWidgets/` — the Rush-challenge Dynamic Island/Lock Screen
  Live Activity. `RushActivityAttributes` is the shared payload (must stay in both targets — see
  `project.yml`'s `VerbumWidgets.sources`).
- `Verbum/Core/Components/` — `NotificationManager`, `HapticManager`, `SoundManager`,
  `LanguageManager` (UI-string language switch, separate from word language), `Analytics` (local
  `os.Logger` only — no data leaves the device), `SpeechService`, `SpotlightIndexer`.
- `Verbum/Features/WordFeed/` — the main swipe feed (`WordFeedView`/`WordFeedViewModel`).
- `Verbum/Features/Lexicon/` — the personal collection + notes (the retention core, per the earlier
  product-strategy council sessions in chat history).
- `Verbum/Features/Practice/` — opt-in games (`QuizView`, `FillGapView`, `GuessWordView`,
  `SynonymsView`) + timed challenges (`ChallengeView` — Perfection/Rush/Sprint, feeds the quarterly
  points leaderboard, Rush drives the Live Activity) + `PracticeMenuView` (hub).
- `Verbum/Features/Profile/` — `ProfileView` (merged hub: premium, vocabulary, settings, account,
  community — `SettingsView` as a separate screen no longer exists), `PremiumSheet`.
- `research/` — audit/word-generation prompts (reusable templates, read their headers).
- `docs/` — `APP_STORE_LISTING.md` (submission copy), `BACKEND.md` (VERBUM_BACKEND provisioning),
  `privacy.html` (needs hosting), `RECRUITING.md`.
- `_LocalDev-Disabled/` — the three real service implementations (§5) only. Nothing else belongs
  here; the old widget snapshot that used to live here was deleted 2026-06-27 (§6.2).

---

## 10. Testing

`VerbumTests/StreakEngineTests.swift` and `CloudKitMergeTests.swift` cover the pure logic
(streak/freeze math, CloudKit LWW merge). They have never been run by the author (§2) — run them
first thing in real Xcode; they're the fastest signal that the environment is sane before you trust
anything else.
