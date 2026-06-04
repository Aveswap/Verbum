# Verbum — Project Handoff

**Last updated:** 2026-05-31
**Branch:** `main`
**Latest commit:** 789 pre-release audit remediation (see §11) — Swift 6, IAP/privacy/widget cleanup, uk dedup, first unit tests

This document is meant to onboard a fresh contributor (human or agent) cold. Read top-to-bottom. Code references use `Path/To/File.swift:LineNumber` so they're clickable in most editors.

---

## 1. The product

**Verbum** is an iOS vocabulary learning app — swipe-feed of curated English words, soft paywall, gamified retention. Native SwiftUI, dark mode only, iOS 16+.

**One-line pitch:** Master 1,000+ words by swiping one a day; pay to unlock past your level's first 50.

### Stack

| Layer | Tech |
|---|---|
| UI | SwiftUI (iOS 16+) |
| Data | GRDB 6.29 / SQLite + FTS5 / Codable structs |
| Sync | CloudKit private DB (per-user UserProfile record) |
| Auth | Sign in with Apple (`AuthenticationServices`) |
| Subscriptions | StoreKit 2 |
| Speech | `AVSpeechSynthesizer` (`SpeechService` shared instance) |
| Haptics | `CoreHaptics` (`HapticManager`) with NSRecursiveLock |
| Social | GameKit (`GameCenterService`) |
| Spaced repetition | FSRS-4.5 algorithm (17-weight model) in pure Swift (`FSRS.swift`) |

### Codebase layout (Swift)

```
Verbum/
├── App/
│   ├── VerbumApp.swift           ← @main entry, injects 4 @StateObjects
│   └── AppCoordinator.swift      ← decides Onboarding vs WordFeed
├── Core/
│   ├── Components/               ← HapticManager, NotificationManager,
│   │                               SoundManager, SpeechService, ConfettiView,
│   │                               ProgressBar, PillButton, ...
│   ├── Data/
│   │   ├── WordAccess.swift      ← *** soft-paywall source of truth ***
│   │   ├── WordRepository.swift  ← @MainActor catalogue
│   │   ├── WordDatabase.swift    ← GRDB / SQLite layer
│   │   ├── WordStore.swift       ← @MainActor UserProfileStore lives here
│   │   ├── FSRS.swift            ← FSRS-5 algorithm
│   │   ├── CloudKitSyncManager.swift
│   │   ├── SubscriptionManager.swift
│   │   ├── AuthService.swift
│   │   ├── GameCenterService.swift
│   │   ├── DatabaseDownloadManager.swift
│   │   ├── TranslationStore.swift
│   │   └── KeychainHelper.swift
│   ├── Models/                   ← UserProfile, Word, Badge, …
│   └── Theme/                    ← Colors, Typography, Spacing
├── Features/
│   ├── WordFeed/                 ← main feed (WordFeedView + VM + WordCardView)
│   ├── WordDetail/               ← word zoom screen
│   ├── WordList/                 ← reusable list (Favorites, Liked, History, Deck contents)
│   ├── Categories/               ← bucket grid, FilterKind drill-down
│   ├── Practice/                 ← Quiz / FillGap / Synonyms / GuessWord / LevelTest / Challenges
│   ├── Quiz/                     ← BatchQuiz (mid-feed quiz of last 5 swipes)
│   ├── Decks/                    ← custom word collections
│   ├── Stats/                    ← streak hero, mastery counts, weekly opens
│   ├── Profile/                  ← user dashboard + SettingsView + PremiumSheet
│   ├── Leaderboard/              ← personal progress + GameKit global
│   ├── Share/                    ← ShareableWordCard + WordShareSheet (image renderer)
│   └── Onboarding/               ← 6-step flow including CommitmentView
├── Resources/                    ← words.json (bundle, 150 words), translations.json (uk only)
└── Verbum.storekit               ← StoreKit Configuration File (3 products)
scripts/
├── generate_1000_words.py        ← Claude Opus 4.7 generator, 50/50/50 PLAN
├── WORDS_DB_PIPELINE.md          ← end-to-end content pipeline doc
├── STOREKIT_TESTING.md           ← StoreKit Configuration setup + test scenarios
└── (legacy) generate_words.py, import_batch.py, PROMPT_FOR_CLAUDE_PRO.md
```

---

## 2. The paywall model (load-bearing)

**This is the central business decision** and threads through every screen. Implemented in [Core/Data/WordAccess.swift](Verbum/Core/Data/WordAccess.swift).

```
Free user, level = Beginner   → 50 words, sorted by frequencyRank ASC,
                                from non-premium categories only.
                                Same 50 every launch (deterministic).
Free user, level = Intermediate → 50 different words at Intermediate level
Free user, level = Expert       → 50 different words at Expert level
Premium user                    → all words at their current level
```

### Rules

- **Free limit:** `WordAccess.freeLimit = 50` per level
- **Premium DB-categories** (`WordAccess.premiumDbCategories`): `Technology`, `Science`, `Literature`, `Society`
- **Free pool selection:** sort by `frequencyRank` ASC, then by `text` lowercased as tiebreaker (stable for bundled JSON without ranks)
- **Locked words DON'T count** as seen / for daily goal / for batch quiz progress / for FSRS
- **WordCheck onboarding test** can only UPGRADE level, never downgrade
- **Level change in Settings** → no explicit reset; state derives from `seenWordIds` ∩ `level` so a fresh 50 naturally appears
- **Practice games + Challenges** filter pool through `WordAccess.canAccess(_:isPro:userLevel:)`
- **End of free pool:** `WordFeedViewModel.isFreePoolExhausted(seenIds:)` triggers a paywall card replacing the next WordCardView
- **Last-5 counter:** orange "N free words left" badge in feed top bar
- **Notifications** sample only from `WordAccess.freePool(level:)` — never leak words above user's level
- **Share gate:** free user can't share locked words (tap → premium sheet)

### Pricing

| Product ID | Type | Price | Trial |
|---|---|---|---|
| `pro_monthly` | Auto-renew | $4.99 / mo | none |
| `pro_yearly` | Auto-renew | $24.99 / yr | 1-week free |
| `pro_lifetime` | Non-consumable | $59.99 once | n/a |

StoreKit Configuration file at [Verbum/Verbum.storekit](Verbum/Verbum.storekit) ready to wire into the Scheme (see [scripts/STOREKIT_TESTING.md](scripts/STOREKIT_TESTING.md)).

---

## 3. Data model

### UserProfile (in [Core/Models/UserProfile.swift](Verbum/Core/Models/UserProfile.swift))

Codable struct persisted to UserDefaults + CloudKit. Mutated through `UserProfileStore` (@MainActor class).

Important fields:
- `name`, `age`, `gender`, `nativeLanguage`, `level`, `appleUserID`
- `currentStreak`, `longestStreak`, `lastOpenedDate`, **`streakTimezone`** (locked at first daily open), **`streakFreezes`**, `streakFreezeUsedDates`
- `seenWordIds: [UUID]` — array form, but `UserProfileStore` keeps `seenSet: Set<UUID>` for O(1) `markWordSeen`
- `totalPoints`, `quarterlyPoints`, `quarterlyResetDate`, `earnedBadges`
- `dailyOpens: [Date]` (last 7) — for StatsView weekly dots
- `dailyGoal: Int = 5`, `wordsLearnedToday`, `wordsLearnedDate`
- `wordMastery: [String: Int]` keyed by UUID string (0-5 mastery dots)
- `decks: [WordDeck]`
- `reviews: [String: WordReview]` — FSRS-5 state per word
- `challengeHighScores: [String: Int]` keyed by ChallengeKind raw
- `profileUpdatedAt: Date` — drives CloudKit timestamp-based LWW merge

### Word (in [Core/Models/Word.swift](Verbum/Core/Models/Word.swift))

```
id, text, phonetic, partOfSpeech, definition, exampleSentence,
synonyms, antonyms, collocations, category, level, etymology,
frequencyRank, register, domainTags
```

`isNew: Bool` is deprecated — kept only for Codable backward compatibility. UI uses `word.isNew(for: seenSet)` extension instead.

### WordReview (FSRS-5)

`stability` (S), `difficulty` (D), `elapsedDays`, `scheduledDays`, `reps`, `lapses`, `state` (new/learning/review/relearning), `lastReview`, `dueDate`.

---

## 4. Status — what's done

✅ marks shipped to `main`. Each row is a discrete commit.

### From the 22-item audit (Task 1 bugs)
All 22 items fixed.

### Phase B gamification
- Daily goal slider (1–30, default 5)
- Confetti + goal toast
- Streak freeze (+1 per 7-day milestone, cap 3, auto-spends on missed days)
- Word mastery 0–5 (dots in feed card + WordRow)
- Onboarding commitment device

### Bigger features
- **FSRS-5** spaced repetition + due-review front-loading in feed
- **Challenges** — Perfection / Rush / Sprint with timers + high scores
- **GameKit** authentication + global leaderboard
- **CloudKit** timestamp-based LWW merge (`profileUpdatedAt` field)
- **Decks** — create / delete / add-from-WordDetail menu
- **50-word soft paywall** (the central model — see §2)
- **Real-word notifications** filtered by user level
- **Shareable word card** — 1080×1080 ImageRenderer + ShareLink

### Polish / docs
- `Verbum.storekit` + [STOREKIT_TESTING.md](scripts/STOREKIT_TESTING.md)
- `generate_1000_words.py` + [WORDS_DB_PIPELINE.md](scripts/WORDS_DB_PIPELINE.md) (PLAN set to 50/50/50 seed)
- `HANDOFF.md` (this file)

---

## 4.5 Code-review remediation — 2026-05-29

Worked through the full technical code review (`678verbum_code_review.md`) — all 27
findings across 6 tiers addressed. Grouped by area:

### Build breakers (Tier 1)
- **Duplicate types resolved.** `DecksView`, `ShareableWordCard`, `WordShareSheet` each
  now exist in exactly one file. Canonical: `Features/Profile/DecksView.swift` and
  `Features/WordList/`. Deleted orphan folders `Features/Decks/`, `Features/Share/`,
  `Features/Share 3/`. The kept `DecksView` merges the themed UX (AppColors, "Create First
  Deck" CTA, empty-deck→Categories hop) with the correct `List`-based swipe-to-delete.
- `DatabaseDownloadManager.remoteURL` made optional + guarded (no force-unwrap landmine).

### Data loss / integrity (Tier 2)
- **seenSet** rebuilds whenever `profile` is replaced (was stale after a CloudKit pull →
  re-counted seen words toward the daily goal).
- **CloudKit scalar merge** now keys on a new `settingsUpdatedAt` (bumped only when a
  user-editable scalar actually changes), not a global mtime — so a device that only swipes
  words can no longer clobber another device's settings edit. `onboardingCompleted` moved
  under this rule so `resetOnboarding()` sticks.
- **CloudKit now syncs the heavy/high-value fields** it previously dropped: `reviews` (FSRS),
  `decks`, `wordMastery`, `challengeHighScores`, streak freezes/dates, daily counters,
  practice gate. Merge: FSRS by latest `lastReview`, mastery/scores by max-per-key, decks
  union-by-id (fuller deck wins), daily counters by later-date-then-max.
- **Streak freeze** only spent when it fully covers the gap (was burning freezes AND
  resetting the streak on a partial cover).

### Logic / UX (Tier 3)
- Batch quiz now tests the real last **5** words (current card was excluded — off-by-one).
- **No quiz repeats** within a round across all five practice modes (Quiz, FillGap, Synonyms,
  GuessWord, Challenge); endless/short pools reuse gracefully without back-to-back repeats.
- Deleted the dead second paywall gate in `WordRepository` (`feedWords`/`canAccess`).
- Daily-goal celebration uses `>=` crossing detection (was `==`, misfired if goal lowered).
- Removed the no-op ternary in Sprint advance.
- **UUID casing bug** (broader than the review flagged): the bundled DB stores ids lowercase
  but `UUID.uuidString` is uppercase and the `id` column is case-sensitive — so
  `fetchWords(ids:)` silently returned nothing (decks/favorites/history). Fixed with
  `COLLATE NOCASE` on id queries + lowercase normalization in the import path. Translation
  lookup fixed the same way.
- FTS search query is now quoted/escaped (was throwing on punctuation and swallowed by
  `try?` → empty results).
- CloudKit pulls on every foreground (`scenePhase == .active`), not only at sign-in.

### Performance (Tier 4)
- `WordAccess.freePool` memoized per level + id-Set for O(1) `canAccess` (was re-filtering +
  sorting the whole catalog per call, including per-frame during a drag and per bucket×word
  in Categories). `WordAccess.invalidate()` is called on catalog reload.
- Per-swipe widget update now refreshes only the snapshot, not the 14-day timeline (was doing
  14 synchronous translation DB reads on every swipe).
- Bundled-DB **copy** moved off the main thread on first launch / version bump (fast
  synchronous open kept for the common every-launch path; feed upgrades via
  `.wordDatabaseInstalled`).
- Per-card translation read moved to a cancellable `.task` off the main actor.

### Memory / best practices (Tier 5–6)
- Feed banner/hint timers moved from uncancelled `asyncAfter` to lifetime-tied `.task`.
- `BatchQuizViewModel` marked `@MainActor`.
- Deleted the dead `ASAuthorizationController` delegate sign-in path in `AuthService`
  (SwiftUI `SignInWithAppleButton` → `handleSignInResult` is the single path).
- Unverified StoreKit transactions are now `finish()`-ed (purchase + listener) so they don't
  resurface in the queue.
- `FSRS.nextDifficulty` aligned to the FSRS-5 reference (linear damping + mean-reversion to
  `D0(easy)`).
- `SpeechService` extracted from `SoundManager.swift` into its own file (pbxproj updated).

**Note on `onChange(of:)`:** the single-parameter form flagged by the review is *correct* for
the iOS 16 deployment target (the two-parameter form is iOS 17+). Left unchanged by design.

**Verification:** `plutil -lint` passes on the pbxproj; static cross-reference sweep clean.
A full Xcode build was **not** run in this session (the dev box had only Command Line Tools,
no `xcodebuild`) — build in Xcode to confirm before shipping.

---

## 4.6 Follow-up remediation — 2026-05-29 (round 2)

Worked through the older full audit (`456verbum_audit_report.md`). Most of its Task 1/2
items were already fixed; this round closed the remaining in-code items (translations to
de/it/fr intentionally deferred).

**Shipped:**
- **Subscription-ended banner** — `SubscriptionManager` detects Pro→not-Pro (mid-session via
  the `Transaction.updates` listener and across launches via a persisted `wasPro` flag);
  `AppCoordinator` shows an auto-dismissing soft banner.
- **Feed search** — `Features/WordFeed/SearchView.swift`, opened from the top-bar magnifier.
  FTS read off the main actor; results open `WordDetailView` (paywall-gated).
- **Spotlight** — `Core/Data/SpotlightIndexer.swift` indexes the catalogue into CoreSpotlight
  (versioned by `bundledDBVersion`, off-main). Tapping a result deep-links via `.openWord`
  → `VerbumApp.onContinueUserActivity` → `WordFeedView` presents the detail.
- **Stats mastery chart** — distribution bars (New→Mastered) in `StatsView`.
- **seenWordIds** — defensive de-dup on load; documented that it's bounded by catalogue size
  (~1000), so the array form is not a scaling risk at current scale.
- **os.Logger** — shared categories in `Core/Components/Logger+Verbum.swift`; adopted in
  `WordDatabase` (seed/open errors no longer swallowed) and `SpeechService`.
- **FTS tokenizer** — native migration now uses `unicode61 remove_diacritics 2`, matching
  the Python-built bundle (so café == cafe whether the DB is bundled or built natively).
- **Friends/invite** — `GameCenterService.showFriends()` presents the native Game Center
  friends list (GameKit has no API to add friends programmatically); `LeaderboardView` adds
  an "Invite Friends" `ShareLink`.
- **App Store ID** — centralised in `Core/AppInfo.swift` (`appStoreID`, `appStoreURL`,
  `rateURL`); `SettingsView.rateApp()` and the invite link both use it. ⚠️ still a placeholder
  ID — one-line update once registered.
- **Content validators** — `scripts/validate_content.py` (stdlib-only) audits IPA format and
  etymology plausibility in `words_v2.db`; `--online` cross-refs Wiktionary. Current run:
  0 errors, ~14 etymology review-warnings, IPA clean.

**Still blocked / deferred (need your action or a build-capable session):**
- **Real App Store ID** (`AppInfo.appStoreID`) — needs App Store Connect registration.
- **Widget + Apple Watch targets** + **App Group** — must be created in Xcode (code is in the
  repo; see §6 items 24–29). Cannot be done reliably by editing the project file blindly.
- **Swift 6 full strict-concurrency migration** and **DI-instead-of-singletons** — large
  refactors that should only be done with a working compiler (this session had Command Line
  Tools only, no `xcodebuild`). Recommend a dedicated, build-verified pass.
- **de/it/fr translations** — intentionally out of scope this round.

⚠️ **Not build-verified:** all round-2 changes were validated by inspection + `plutil -lint`
on the project file only. Build in Xcode before shipping.

---

## 5. Outstanding TODOs

Numbered for cross-reference with the audit. Grouped by impact.

### 🟠 IMPL — code work

| # | Item | Impact | Effort |
|---|---|---|---|
| 1 | **Word of the Day Widget** (WidgetKit + App Group) | High | 3-4 days (new Xcode target) |
| 2 | **Apple Watch glance** — daily word on wrist | High | 2-3 days (new Xcode target) |
| 3 | **Translation pipeline for 4 languages** (uk → then de, it, fr — see §6 Content strategy) | High | uk: ~½ day + ~$3 Claude API; per extra lang: ~½ day + ~$3 |
| 4 | **Search bar in feed/home** — quick lookup outside Categories | Medium | ½ day |
| 5 | **Spotlight Search integration** — words findable from iOS Spotlight | Medium | ½ day |
| 6 | **Onboarding feed preview** — sample card before commitment for higher conversion | Medium | ½ day |
| 7 | **Stats: mastery distribution chart** (bar chart 0→5) | Low-Med | ½ day |
| 8 | **Subscription-ended soft notification** ("Your subscription has ended") | Medium | ½ day |
| 9 | **Real friends invite flow** (Share invite link → GameKit friend add) | Medium | 1-2 days |
| 10 | **DB versioning manifest** (sha256 + UserDefaults check in DatabaseDownloadManager) | Low | ½ day |
| 11 | **First-launch empty-state CTA** (prominent "Download full dictionary") | Low | ½ day |
| 12 | **Etymology validator** via Wiktionary API (Python, runs after generation) | Low | 1 day |
| 13 | **IPA validator** via eng-to-ipa library (Python) | Low | ½ day |

### 🟡 ARCH — deferred refactors

| # | Item |
|---|---|
| 14 | Strict Concurrency Swift 6 full migration (enable flag + fix warnings) |
| 15 | Dependency Injection instead of singletons (for unit tests) |
| 16 | `os.Logger` everywhere — currently only in CloudKitSyncManager |
| 17 | `seenWordIds` Set persistence — only matters at >5k word catalog |
| 18 | Verify `WordDatabase` migrations use `unicode61 remove_diacritics 2` tokenizer (Python generator does, native Swift migration unverified) |

### ⚙️ MANUAL — non-code blockers

| # | Item | Blocker | Status |
|---|---|---|---|
| 19 | Run `generate_1000_words.py` → upload `words_v2.db` to CDN | Needs `ANTHROPIC_API_KEY` + CDN account (Cloudflare R2 recommended) | ❌ not done |
| 20 | Replace `itms-apps://itunes.apple.com/app/id` in [SettingsView.swift](Verbum/Features/Profile/SettingsView.swift) `rateApp()` with real App Store ID | App Store Connect registration | ❌ not done |
| 21 | Enable Game Center capability in Xcode + create leaderboards `com.verbum.app.quarterly_points` and `com.verbum.app.all_time_points` | App Store Connect | ❌ not done |
| 22 | Wire `Verbum.storekit` into Scheme → Run → Options → StoreKit Configuration | Manual one-time in Xcode | ❌ not done |
| 23 | Add `Verbum.storekit` to the project file (right-click `Verbum` group → Add Files) | Manual | ❌ not done |

#### Widget + Apple Watch — Xcode wiring (code is in repo, targets are not)

Code shipped in commit `4334f56`. The two extension *targets* themselves still
need to be created in the Xcode project, and the App Group capability has
to be enabled on all three targets. Full step-by-step in
[scripts/WIDGET_AND_WATCH_SETUP.md](scripts/WIDGET_AND_WATCH_SETUP.md).

| # | Item | Status |
|---|---|---|
| 24 | Apple Developer portal → Identifiers → enable **App Groups** capability + create `group.com.verbum.app` (only required for App Store / paid Developer Program; for simulator + Personal Team development Xcode auto-provisions it) | ❌ not done |
| 25 | Xcode → **main Verbum target** → Signing & Capabilities → **+ App Groups** → check `group.com.verbum.app` (entitlement file already declares it, the capability still needs to be added in the target UI so Xcode signs against it) | ❌ not done |
| 26 | Xcode → **File → New → Target → Widget Extension** → name `VerbumWidget` → drag the four files from [`VerbumWidget/`](VerbumWidget/) into the new target → set target membership for each | ❌ not done |
| 27 | Xcode → **File → New → Target → Watch App** → name `VerbumWatch` → drag both files from [`VerbumWatch Watch App/`](VerbumWatch%20Watch%20App/) into the new target | ❌ not done |
| 28 | On **both extension targets**: Signing & Capabilities → **+ App Groups** → check `group.com.verbum.app` | ❌ not done |
| 29 | On **both extension targets**: add target membership for [`Verbum/Core/Data/SharedWordStore.swift`](Verbum/Core/Data/SharedWordStore.swift) — and ONLY that file, **not** `Colors.swift` or the rest of `Core/` | ❌ not done |

Until these manual steps are done, the widget never appears in the system
widget gallery and the watch app can't be installed onto the simulator/device.
The main app keeps publishing the timeline regardless — it's a no-op on the
write side until extensions are listening.

---

## 6. Open questions

1. **Real CDN URL** — `DatabaseDownloadManager.remoteURL` is currently `https://cdn.verbum.app/words_v1.db` (placeholder). The `#warning` in `startIfNeeded()` is intentional; update before App Store submission.
2. **Privacy policy + terms URLs** — `PremiumSheet.footerLinks` points to `https://verbum.app/privacy` and `https://verbum.app/terms`. These must be live pages before App Store review.
3. **App icon set** — there's an `AppIcon.appiconset` placeholder. Real icon TBD.
4. **Default Apple Sign-In flow** — works in code; needs the App ID to have the Sign in with Apple capability provisioned. Verify before submission.
5. **Russian language** — explicitly removed from `NativeLanguage` enum. Decision is final; don't re-add.

### Word generation progress — 2026-05-28

Words are being authored **by Claude directly in chat** (no Anthropic API key
needed) as JSON batches in `scripts/word_batches/`, then assembled locally by
`scripts/import_batches.py` into `scripts/words_v2.db`.

**Current: 1000 / 1000 words committed — COMPLETE ✅** (all validate, 0 duplicates):

| Level | Have | Target | Remaining |
|-------|-----:|-------:|----------:|
| Beginner | 300 | 300 | 0 ✅ |
| Intermediate | 450 | 450 | 0 ✅ |
| Expert | 250 | 250 | 0 ✅ |

**The 1000-word catalog is finished.** Next phases: integrate `words_v2.db`
(CDN upload + `DatabaseDownloadManager.remoteURL`), then UA translations,
then de/it/fr.

✅ **Free pool complete** — 50 non-premium words at every level, so
`WordAccess.freePool(level:)` is fully satisfied.
✅ **Premium complete at all levels** — Technology / Science / Literature /
Society each have Beginner + Intermediate + Expert content.

Batches committed:
- `batch_01_beginner_freepool.json` (50) — B2-C1 recognizable
- `batch_02_intermediate_freepool.json` (50) — C1-C2 less common
- `batch_03_expert_freepool.json` (50) — C2 rare/interesting
- `batch_04_premium_beginner.json` (54) — Tech/Science/Literature/Society
- `batch_05_premium_intermediate.json` (50)
- `batch_06_premium_expert.json` (36)
- `batch_07_intermediate_expansion.json` (50) — non-premium intermediate
- `batch_08_beginner_expansion.json` (50) — non-premium beginner
- `batch_09_expert_expansion.json` (50) — non-premium expert
- `batch_10_intermediate_expansion.json` (50) — non-premium intermediate
- `batch_11_intermediate_expansion.json` (50) — non-premium intermediate
- `batch_12_beginner_expansion.json` (50) — non-premium beginner
- `batch_13_intermediate_expansion.json` (50) — non-premium intermediate
- `batch_14_expert_expansion.json` (50) — non-premium expert
- `batch_15_beginner_expansion.json` (50) — non-premium beginner
- `batch_16_intermediate_expansion.json` (50) — non-premium intermediate
- `batch_17_expert_expansion.json` (50) — non-premium expert
- `batch_18_beginner_expansion.json` (50) — 46 beginner (finishes Beginner) + 4 expert
- `batch_19_intermediate_expansion.json` (60) — 50 intermediate + 10 expert (finishes Expert)
- `batch_20_intermediate_expansion.json` (52) — intermediate (finishes catalog at 1000)

**Calibration (confirmed by user):** every word must be *interesting* — never
primitive. The level reflects how often a learner *encounters* the word, not
raw difficulty:
- **Beginner** = B2-C1, interesting but likely already heard (serene, eloquent)
- **Intermediate** = C1-C2, encountered occasionally (ambivalent, sardonic)
- **Expert** = C2, rarely or never met (ineffable, perspicacious, sangfroid)

**To resume generation next session:**
1. Read this table + the existing batch files to see which words are already used
2. Author new `batch_NN_*.json` files in `scripts/word_batches/` avoiding ALL
   existing words (importer rejects duplicates by text + id)
3. Use valid UUID v4 ids (the importer enforces the variant rule — if unsure,
   run `python3 -c "import json,glob,uuid; ..."` to reassign)
4. Register must be one of: formal, informal, neutral, slang, archaic
   (NOT "literary" — use "formal" and put "literary" in domainTags instead)
5. Category must be exactly one of the 12 DB-categories
6. `cd scripts && python3 import_batches.py --validate` then `python3 import_batches.py`
7. Commit each batch with a per-batch message

Remaining work: NONE — all 1000 words are authored, validated, and committed.
The 8 non-premium categories (Body, Character, Communication, Emotions, Food,
General, People, Psychology) plus the 4 premium categories are all covered
across every level.

### Content strategy — revised 2026-05-28

The original audit listed 13 native languages. **Scope reduced to 4**: Ukrainian (uk), German (de), Italian (it), French (fr) + "Other". Translation rollout is staged:

1. **Phase 1 — Complete the catalog ✅ DONE + integrated (bundled)**
   - 1000 words authored as JSON batches, assembled by `import_batches.py` into
     `scripts/words_v2.db` (300/450/250, 0 dups).
   - **Delivery decision: bundle in app (not CDN).** The DB is only 647 KB.
     `Verbum/Resources/words_v2.db` is committed and added to the **Verbum** app
     target (pbxproj). `WordDatabase.seedFromBundleIfNeeded()` copies it into the
     writable Application Support dir on first launch (and re-seeds when
     `bundledDBVersion` is bumped on an app update). `DatabaseDownloadManager` is
     now dormant (kept as a future OTA hook).
   - **To update words later:** rebuild `scripts/words_v2.db`, copy it to
     `Verbum/Resources/words_v2.db`, and bump `WordDatabase.bundledDBVersion`.
2. **Phase 2 — Ukrainian translations only**
   - Write `generate_translations.py` script (TBD)
   - Populate `translations` table for `lang='uk'`
   - Ship — UA users get full L1 support, other free users see "translation coming soon" indicator (already implemented)
3. **Phase 3 — German + Italian + French**
   - Re-run translation script with `--langs de,it,fr`
   - Push updated `words_v2.db` to CDN, bump version

The reduced NativeLanguage enum is already shipped. Existing user profiles holding any of the removed locales (es/pt/pl/zh/ja/ko/ar/tr/hi) decode to `nil` via `flatMap(NativeLanguage.init)` and are treated as having no L1 selected — no crash, just no translation surfaced.

---

## 7. Constraints the user has set

These are non-negotiable choices from prior sessions:

- **Dark mode only** — `AppTheme` enum has only `.dark`; don't add light theme controls.
- **iOS 16+ minimum.** SwiftUI features chosen accordingly (no iOS 17-only APIs like `MainActor.assumeIsolated`).
- **Free pool size = 50 per level**, not 30, not 300. Decision made 2026-05-27.
- **Premium DB-categories stay completely locked for free users** (no "browse + locked words inside" — the bucket itself is the gate). User said: *"юзер не може заходити туди, ці категорії і слова відкриються після оплати"*.
- **WordCheck onboarding test never downgrades** the user-picked level. User-picked level is the floor.
- **50 free words remain forever-playable** — practice/decks/review keep working after the user hits the paywall; only NEW word exposure requires premium.
- **Locked words do not count** toward seen / daily goal / batch quiz / FSRS reviews (was a bug, fixed).
- **Frequency-rank ordering** for free pool selection (not random, not curated, not by user id) — "найкорисніші слова перші".
- **Notifications must match user's level** — never push a locked word to a free user's lock screen.
- **Russian is permanently removed** from native language picker.
- **No light mode toggle** in Settings.
- **All future word generation skips Technology / Science / Literature / Society** for free seed; those categories belong to premium content phase 2.

---

## 8. Key decisions made today

The session that produced the current `main` state nailed down the paywall model. Quote-form record so the next agent doesn't re-litigate:

1. **Pool size:** 50 per level. *"давай так, у нас буде 30 слів всього безкоштовно … окей давай збільшимо пул слів до 50"*
2. **Selection method:** frequencyRank ASC, excluding premium categories. *"(a) За frequencyRank ASC — найкорисніші слова перші (рекомендую), але слово не з Premium категорії"*
3. **Post-exhaustion UX:** hybrid wall — counter on last 5, paywall card after; the 50 stay free forever for practice. *"(c) Hybrid — counter '5 left, 4 left...' на останніх 5 free, потім paywall. але і юзер буде мати можливість тренуватися з тими 50 словами які були безкоштовними"*
4. **Premium categories:** stay locked entirely; free pool just excludes their words. *"Категорії — премʼюм-бакети ламаються? не ломаються, бо ми не будемо давати в тих 50 слів слова з преміум категорій"*
5. **Initial DB:** 50/50/50 = 150 seed; premium content generated later. *"загально буде спочатку 50 слів для beginner, 50 для intermediate і 50 для expert. далі до кожного рівня будуть ще слова, ми це реалізуємо пізніше"*
6. **Locked tease copy:** *"Unlock N more Beginner/Intermediate/Expert words"*, N = unseen count at user's level
7. **Practice after exhaustion:** free user keeps practicing on their 50; premium needed for new words. *"Variant: After 50 — Practice показує paywall теж"* combined with #3
8. **Level change in Settings:** fresh 50 from new level. *"Скидаємо free counter? (новий пул 50 слів)"* — implemented by deriving state from `seenWordIds`, no explicit reset code needed
9. **Voice card** removed from Customize section (was a placeholder, user chose to hide entirely)
10. **Categories card** unlocked from `customizeSection` — opens `CategoriesView`

---

## 9. Where to resume

If you (or another agent) pick this up cold:

1. **Read** [Core/Data/WordAccess.swift](Verbum/Core/Data/WordAccess.swift) first. It's the heart of the paywall model.
2. **Skim** [Core/Models/UserProfile.swift](Verbum/Core/Models/UserProfile.swift) for the data shape.
3. **Build + run** in Xcode with the simulator. Wire up `Verbum.storekit` per [STOREKIT_TESTING.md](scripts/STOREKIT_TESTING.md) so the paywall is testable.
4. **Verify in-app:** free user only sees 50 words at their level; locked previews show "Unlock N more Beginner/Intermediate/Expert words"; paywall card appears after the 50th swipe; practice games filter through `WordAccess.canAccess`.
5. **Pick** an item from §5. Recommended next: **#3 (translations 13 languages)** for impact, or **#4 + #5 (search + Spotlight)** as a sub-day combined ship.

### Common gotchas

- **Dropbox conflict copies** — the project lives in iCloud Drive/Dropbox; periodic stray `Decks 2/`, `Practice 4/` folders appear. `git status` reveals them; delete them and continue.
- **Xcode auto-syncs `project.pbxproj`** when files are added through the Finder. Commit those edits with your Swift changes.
- **`generate_1000_words.py` is resumable** via `progress_v2.json`. If a generation slice fails validation 3×, the script logs FAILED and continues — re-run later.
- **GameKit submissions silently no-op** if Game Center capability isn't enabled. The code is correct; the manual ASC setup is the blocker.
- **CloudKit zone `VerbumZone`** is created lazily on first push. If you wipe the simulator's iCloud data, the zone gets recreated automatically.

### Quick-check commands

```bash
# project root
cd /Users/dmytrotriukh/Library/CloudStorage/Dropbox/_verbum/Verbum

# what's modified
git status --short

# count Swift files / lines
find Verbum -name '*.swift' | wc -l
find Verbum -name '*.swift' -exec wc -l {} + | tail -1

# verify bundled JSON word counts per level
python3 -c "
import json
from collections import Counter
words = json.load(open('Verbum/Resources/words.json'))
print(Counter(w['level'] for w in words))
"

# check free pool would be valid
python3 -c "
import json
from collections import Counter
words = json.load(open('Verbum/Resources/words.json'))
premium = {'Technology','Science','Literature','Society'}
free_pool = [w for w in words if w['category'] not in premium]
print('Free pool size:', len(free_pool))
print('By level:', Counter(w['level'] for w in free_pool))
# Should show ≥50 per level for the model to work
"
```

---

## 10. Git log (recent shape)

```
77ccf23 feat: shareable 1080×1080 word card for organic growth
0750d33 feat: level-locked 50-word free pool soft paywall
4e95d29 chore: locked preview cadence 12 → 35 (later overridden by soft paywall)
2b0f82f fix: feed cadence, quiz checkmark jitter, decks browse, premium overlap
4c8b0da fix: locked-word bookkeeping, never-downgrade level test, premium testing infra
b224a08 docs: 1000-word generation pipeline + scripts
d3e3c6e fix: CloudKit merge by profileUpdatedAt timestamp (proper LWW)
7cdc7de feat: Game Center leaderboard integration
011825f feat: Challenges — Perfection / Rush / Sprint game modes
fbeca99 feat: FSRS-5 spaced repetition scheduler
dde3305 feat: gamification polish — decks, mastery surfacing, real word notifications
d8af8ab feat: deep audit fixes (Phase A bugs + Phase B gamification)
```

---

## 11. 789 Pre-Release Audit — remediation (2026-05-31)

Worked the full `789Verbum_PreRelease_Audit.md` end-to-end. **Nothing was skipped.** Committed
in logical phases (each commit message names the audit item numbers). Build NOT verified — this
machine has Command Line Tools only (no `xcodebuild`); everything below is static-reviewed and,
where possible, validated with `plutil -lint`, `sqlite3`, and the Python validator.

### What changed, by area

**Correctness / data-loss (§1)**
- CloudKit push is gated behind the first successful pull (`UserProfileStore.hasCompletedInitialPull`)
  so a fresh install can't blind-overwrite the server before merging it in (1.1).
- `push()` now merges into the existing server record and retries once on `serverRecordChanged`;
  `pull()` marks initial-pull-complete on both the merged and `.unknownItem` paths; zone creation
  is cached (1.2, 1.11).
- `seenSet` rebuild is a membership check, not identity (1.5). `streakFreezes` merge follows the
  most-recently-updated profile, clamped to the cap (1.11).
- `todaysWord(language:)` is language-scoped with a stable `ORDER BY frequencyRank, id` instead of
  a raw physical-row offset (1.3). `fetchWords(ids:language:)` + `WordRepository.words(ids:)` scope
  saved lists to the active language (1.6). Daily-word notifications sample the language-correct
  free pool and re-schedule on language change; badge cleared on launch (1.7).
- `WordDatabase.dbQueue` is guarded by `OSAllocatedUnfairLock` (the old "main-thread-only" comment
  was violated by the seeding background queue) (1.4).
- `runMigrations()` logs schema drift — expected-but-unapplied / applied-but-unknown (5.3).
- `checkQuarterlyReset()` advances the anchor one exact quarter at a time (no drift, no skipped
  boundaries) and awards the first closed quarter's badge even after a long absence (1.10).
- Pro feed orders unseen words first (then seen), so returning Pro users get new vocabulary before
  the catalogue recycles (1.8). `WordFeedViewModel.seenWordIds` is fed from the view like `dueReviewIds`.
- FSRS relabelled **FSRS-4.5** (17-weight) everywhere — it deliberately omits FSRS-5's short-term
  weights; the app surfaces a word at most once/day so they don't matter (1.9).

**App Store readiness (§2, §3.5)**
- `PremiumSheet` shows only live StoreKit products with localized `displayPrice`; the yearly
  "/mo · Save X%" note is computed from real prices. No products → honest "couldn't load · Retry"
  state (driven by `SubscriptionManager.loadFailed`), no fake `$`-rows, no dead buy button.
- Lapse banner only shows after a trustworthy entitlement check (`hasCheckedEntitlements`,
  gated again in `AppCoordinator`) — no false "subscription ended" flash on cold launch (3.5).
- `Info.plist`: `ITSAppUsesNonExemptEncryption=false` (set via `project.yml` so regen keeps it).
- Entitlements: removed unused `aps-environment` (no push, only local notifications).
- `PrivacyInfo.xcprivacy`: dropped the false Analytics purpose; **added a widget manifest**
  (`VerbumWidget/PrivacyInfo.xcprivacy`, UserDefaults reason CA92.1).
- **Widget rework:** home-screen widgets now come solely from `WordOfDayWidget` (real,
  language/level-aware App-Group timeline). Removed the duplicate `words.json`-backed English-only
  small/medium widgets; rebuilt the lock-screen widgets on the same `SharedWordStore` source.
  `words.json` is no longer bundled into the widget (still bundled in the app as a fallback).
  **Also wired the widget's App-Group entitlement, which was missing in the project** — the widget
  literally could not read shared data before.

**Project source-of-truth (§5)**
- `project.yml` is now faithful (entitlements, app icon, device family, **Swift 6 + strict
  concurrency `complete` for app, widget, and tests**, shared scheme, `ITSAppUsesNonExemptEncryption`)
  and `.xcodeproj` was **regenerated from it with `xcodegen`** — resolving the project.yml↔pbxproj
  Swift-version drift the audit flagged. ⚠️ **Regenerate via `xcodegen generate` from now on**;
  hand-edits to the pbxproj will be lost (schemes are defined in `project.yml`).

**UX / content (§3, §4)**
- `CommitmentView` discloses the 50-word/level free cap whenever the 30-day projection exceeds it (3.2).
- Accessibility (3.4): VoiceOver labels on the feed top bar, card action row (state-aware) and
  pronounce buttons, and the detail toolbar; Dynamic Type ceiling on the detail screen.
- Graceful empty fields (4.1): phonetic pill omitted when a word has no IPA (e.g. Ukrainian), on
  both card and detail. Etymology/synonyms were already gated.
- `WordAccess` gained an overridable `@MainActor catalogProvider` for testability (5.1).
- `validate_content.py` (4.4): language-aware (IPA/etymology only audited for `en`), IPA charset
  gained U+032F, new structural checks (text/definition/level) and catalogue invariants (distinct
  lemmas per language; ≥50 non-premium words per language×level). Full run is **errors=0** across
  all 2,592 words.
- First unit tests (5.4): `VerbumTests` target — WordAccess, FSRS, and CloudKit-merge coverage.
  `CloudKitSyncManager.merge` + helpers were made `static`/internal to test without a CK container.

### ⚠️ DEVIATION from the audit — Ukrainian catalogue (4.1)

The audit recommended **hiding/gating Ukrainian from v1.0** (it lacks IPA/etymology/register/
synonyms and had duplicate lemmas). I did **not** hide it. Instead I:
1. **De-duplicated** the uk catalogue in `build_uk_catalog.py` — 1000 → **892 distinct** lemmas
   (kept the most-frequent variant per lemma). Rebuilt `words_v2.db`, bumped `bundledDBVersion` 18→19.
2. Made the UI **gracefully omit** the empty fields (no empty IPA pill; etymology/synonyms already
   hidden when absent).

**Rationale:** Ukrainian *speakers* (the target — this is a native-speaker app, not a translation
overlay) don't need IPA or English-style etymology, so graceful omission makes uk *acceptable*
rather than *broken*, and preserves the invested content. **If you disagree, hiding uk is a one-line
change** in the language picker (filter `availableLanguages()`); the data still validates clean.

### Manual gates that CANNOT be done in code (must be done in Xcode / App Store Connect)

These are **required before submission** and are outside what this environment can touch:
- **Real App Store ID / `DEVELOPMENT_TEAM`** — `project.yml` has `DEVELOPMENT_TEAM: ""`; set your team
  and signing in Xcode (or via the yml) for all three targets.
- **App Store Connect IAP products** — create `pro_monthly`, `pro_yearly`, `pro_lifetime` (IDs in
  `SubscriptionManager`) with prices/localizations, or the paywall stays in its (correct) "couldn't
  load · Retry" state. Test with a StoreKit config file or a sandbox account.
- **App Group capability** — `group.com.verbum.app` must be enabled on both the app and widget
  App IDs in the developer portal (entitlements files + project wiring are now correct).
- **iCloud/CloudKit + Sign in with Apple capabilities** — confirm enabled for `iCloud.com.verbum.app`.
- **Live Privacy Policy / Terms pages** — `PremiumSheet` links to `https://verbum.app/privacy`
  (Terms points at Apple's standard EULA). The privacy page must actually exist before review.
- **Build + run the unit tests** — couldn't be verified here (no full Xcode). Open in Xcode, build
  all three targets under Swift 6 strict concurrency, and run `VerbumTests` (⌘U).
- The Watch code referenced in earlier handoffs is **not** a target in `project.yml`/pbxproj; if Watch
  support is wanted it must be added as a new target.

### Security reminder (unchanged, still open)

The repo lives in Dropbox with a **GitHub PAT embedded in the git remote URL in plaintext**. Recommend
revoking that token and switching to SSH or a credential helper. Not actioned yet.

---

## 12. German catalogue completion + UI localization (2026-06)

### German → 1,000 words (parity with English)
Authored 250 native German parallels (no anglicisms) for the previously-uncovered English
concepts — 200 intermediate (`scripts/word_batches_de/batch_16–19`) + 50 expert (`batch_20`),
each with IPA, German definition + example, etymology, synonyms, register. German now mirrors
English at **300 / 450 / 250 = 1000**, concept-aligned by `frequencyRank`. Same-lemma collisions
(two English concepts → one German word) were resolved with distinct native synonyms, since
`build_de_catalog.py` dedupes by `text`. Rebuilt `words_v2.db`, bumped `bundledDBVersion` → **20**.
`validate_content.py` now audits German IPA too (`IPA_LANGUAGES += "de"`, charset gained ç ø œ ʏ);
full run is **errors=0** across 2,892 words (en 1000 / de 1000 / uk 892).

### UI localization (en / de / uk) — follows the in-app word-language switch
The interface language tracks the vocabulary language (which defaults to the device language and
is switchable in Settings), so the whole app is in one language. Mechanism:
- **`LanguageManager`** (`Core/Components/LanguageManager.swift`) + a `Bundle` subclass swizzle
  that repoints `Bundle.main` at the chosen `.lproj` **at runtime**, so `Text("…")` resolves
  against it. Keys ARE the English source strings → **no view code changed**; a missing
  translation simply falls back to English (never a crash).
- Wired in `UserProfileStore.applyWordLanguage()` (bootstrap at launch) and `setWordLanguage()`
  (live switch). `VerbumApp` injects `\.locale` and `.id(language)` so the tree rebuilds and
  every `Text` re-resolves on switch.
- Strings live in `Verbum/Resources/{en,de,uk}.lproj/Localizable.strings`, generated by
  `scripts/gen_localizations.py` from a key→(de,uk) map. `project.yml` declares
  `knownRegions: [en, de, uk]`, `developmentLanguage: en`, and `CFBundleLocalizations`.

**Coverage / limits (READ THIS):**
- **247 keys** translated for de & uk — static UI, interpolated format strings, plurals
  (`.stringsdict`, uk one/few/many), **data-driven labels** (part of speech, category, level,
  register — stored canonically English, localized at display via `Word.localizedPartOfSpeech`
  / `localizedCategory` and the enum `displayName`s), notifications, paywall (feature bullets,
  CTAs, legal copy), challenges, and quiz/level-test result messages. Brand/emoji-only strings
  stay English by design.
- **Pronunciation:** `SpeechService` selects the voice for the active word language (de-DE /
  uk-UA / en-US, English fallback if the language pack isn't installed on the device).
- **Demographic onboarding removed:** the age / gender / native-language / "how did you hear" /
  words-per-week screens (not in the current design) were deleted; Settings/Stats no longer show
  gender/age. `UserProfile` keeps those fields for CloudKit/Codable back-compat (just unused).
- **Interpolated** strings are translated too — 28 SwiftUI format keys (`"Best: %lld"`,
  `"Unlock %lld more %@ words"`, the free-pool paywall lines, etc.) in `gen_localizations.py`'s
  `INTERP` map (`%lld` for Int, `%@` for String). If a specifier doesn't match what SwiftUI
  generates at runtime, that one string just falls back to English — no regression.
- **Still English (deliberately):** ternary-plural strings like
  `"\(remaining) free word\(remaining == 1 ? "" : "s")"`. Proper plurals need a `.stringsdict`
  (Ukrainian has one/few/many forms); doing it wrong is worse than the English fallback, so it
  was left as a follow-up. Pure-number strings (`"%lld"`, `"+%lld"`, `"W%lld"`) need no translation.
- **Unverified — no build here (CLT only).** Must be built & run in Xcode: confirm the live
  switch works, that `.lproj` resources are bundled (they're globbed via `sources: Verbum`), and
  spot-check the `%lld`/`%@` specifiers against any string that still shows English. To add a
  language: drop a new `.lproj`, extend `LanguageManager.supported` + `knownRegions`, and add the
  catalogue on the content side.

---

## 13. Content pivot — curated gems only (2026-06)

The 1000-per-language generated catalogue was dropped in favour of a small hand-curated set of
"gem" words (deep-research + authored). Pipeline: `scripts/word_batches_gems/*.json` →
`import_gems.py` → `keep_gems_only.py` (deletes everything not a gem) → `validate_content.py`.
Current size: **de 37 / en 35 / uk 41 = 113** (bundledDBVersion 24).

**Known deficit — backfill later (intentionally deferred):**
- **en/beginner = 0** → empty feed for an English beginner. Highest priority to fill.
- uk/expert thin (≈5, only ~1 non-premium); de/beginner = 6.
- The "50 free words per level" paywall pool is now just the whole small per-level set
  (`validate_content.py`'s ≥50 free-pool check is relaxed to a warning). Monetization needs
  rethinking for a curated set (e.g. N free gems then Pro, or Pro = extra languages/features).

To backfill: add entries to `scripts/word_batches_gems/` (or generate via
`Verbum_DeepResearch_MORE_WORDS.md`), `python3 import_gems.py`, then bump `bundledDBVersion`.
The pre-pivot full catalogue is recoverable from git (`Resources/words_v2.db` at v23).

---

*End of handoff. Good luck.*
