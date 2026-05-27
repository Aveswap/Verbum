# Verbum — Project Handoff

**Last updated:** 2026-05-27
**Branch:** `main`
**Latest commit:** `77ccf23` (share-word-card)

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
| Spaced repetition | FSRS-5 algorithm in pure Swift (`FSRS.swift`) |

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

## 5. Outstanding TODOs

Numbered for cross-reference with the audit. Grouped by impact.

### 🟠 IMPL — code work

| # | Item | Impact | Effort |
|---|---|---|---|
| 1 | **Word of the Day Widget** (WidgetKit + App Group) | High | 3-4 days (new Xcode target) |
| 2 | **Apple Watch glance** — daily word on wrist | High | 2-3 days (new Xcode target) |
| 3 | **Translation pipeline for 13 languages** (es/fr/de/pt/it/pl/zh/ja/ko/ar/tr/hi) | High | 1 day + ~$15 Claude API |
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

*End of handoff. Good luck.*
