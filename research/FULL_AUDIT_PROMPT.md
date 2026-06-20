# Verbum — Full Audit Brief (give this to a reviewer with the project zip)

You are a **40-year-veteran Apple/iOS engineer** — you shipped on the original iPhone SDK, you
think in Instruments traces and crash logs, you have an Apple-school sense of taste, and you are
ruthless about correctness, security, and "does this actually work." Audit the attached Verbum
project **end to end** and report like a senior reviewer: prioritized findings, each with
`file:line`, *why it bites*, and a concrete fix. Lead with a short executive summary and a blunt
verdict.

Be specific, not generic. If something is fine, say so briefly and move on. If something is broken,
prove it.

---

## Critical context (read first — it changes several findings)

- **Stack:** iOS 16+, SwiftUI, **Swift 6 with `SWIFT_STRICT_CONCURRENCY: complete`**, dark-mode only
  (`UIUserInterfaceStyle: Dark`). GRDB/SQLite. **XcodeGen** — `project.yml` is the source of truth;
  the `.xcodeproj` is generated (`xcodegen generate`), never hand-edited.
- **Data:** a bundled, **read-only** `Verbum/Resources/words_v2.db` (~574 English words, FTS5) opened
  in place; `words.json` is a fallback. All user state lives in `UserProfile` (UserDefaults +
  optional CloudKit), not in the word DB.
- **Services are LOCAL-DEV STUBS:** `CloudKitSyncManager`, `AuthService`, `GameCenterService` in
  `Core/Data/` are no-op stubs; the real implementations are in `_LocalDev-Disabled/*.original`
  (out of the build). They're gated by `AppInfo.isSignInConfigured` / `isGameCenterConfigured`
  (both false). This is intentional. Do NOT report "sync does nothing" as a bug — but DO flag any
  place that breaks when the reals are restored.
- **Optional cross-user backend is DORMANT** behind the `VERBUM_BACKEND` compilation flag
  (off by default): `Backend.swift`, `LeaderboardService.swift` (GameCenter), `PublicLikesService
  .swift` (CloudKit public DB). The no-op seam compiles today; the GameKit/CloudKit code only
  compiles when the flag is set. **Specifically verify that the `#if VERBUM_BACKEND` code actually
  compiles and uses correct GameKit/CloudKit API** — it was written without a build.
- **THE AUTHOR CANNOT COMPILE THE PROJECT** (Command-Line-Tools only, no iOS SDK). A large recent
  redesign was **static-reviewed, never compiled.** So **your single most valuable output is: does
  it build under Swift 6 strict concurrency, and where are the compile/type/concurrency errors?**
  Run the compiler. Treat warnings as findings.

### Recent redesign to scrutinize hardest (most likely to harbor bugs)
- **Emotion-first onboarding** (`Features/Onboarding/EmotionOnboardingView.swift`, `Feeling.swift`)
  replaced the old flow; old onboarding files were deleted.
- **Personal lexicon:** "claim" == bookmark; per-word notes (`UserProfile.wordNotes` +
  `noteChangedAt`) with a per-key LWW CloudKit merge (`CloudKitSyncManager.mergeNotesByRecency`).
  `LexiconView` with in-lexicon `.searchable`.
- **Feed changes** (`WordFeedView`): action row trimmed to Save+Share; single-tap→detail,
  **double-tap→like** with a red heart burst; **on-card like count** (`WordLikeDisplay` placeholder
  until backend); center "1/5 + goal" progress is now a button → lexicon; bottom nav removed.
- **Quiz is opt-in** (`UserProfile.quizEnabled`, default false) — gates the after-5-swipes batch
  quiz; **gameplay toggle** in Settings.
- **7-day free-games trial** from first launch (`UserProfile.firstLaunchDate`,
  `UserProfileStore.gamesTrialActive/DaysLeft/markFirstLaunchIfNeeded`, merged "earliest wins");
  local trial-ending notification.
- **Practice hub** (`PracticeMenuView`): challenges (Perfection/Rush/Sprint), practice games, a
  "Words you'll soon forget" review seeded from `UserProfileStore.wordsToReview()` (FSRS-fading
  claimed words), and a moved-in streak/badge/leaderboard `statsHeader`.
- **`Word.displayEtymology`** strips dictionary-citation clauses via regex — verify the regex is
  correct and can't crash or mangle text.
- **`Analytics`** seam (OSLog default) with events app_open / word_claimed / note_added /
  card_shared.

---

## What to audit (cover every section)

1. **Build & compile integrity.** Does it compile under Swift 6 strict concurrency? List every
   error/warning with `file:line`. Check `@MainActor`/`Sendable`/`nonisolated(unsafe)` correctness,
   actor-isolation of the new services (`Analytics`, `Leaderboards`, `PublicLikes`), `.task`/
   `onChange` closures, and the `WordDetailView` `body`→`content` split.
2. **Correctness / logic bugs.** Stress the math and state machines: streak + freezes
   (`StreakEngine`), FSRS reviews + `wordsToReview()`, daily goal, quarterly reset, the **CloudKit
   LWW merges** (likes/bookmarks/notes/firstLaunchDate/streak), the 7-day trial boundary, quiz
   gating, double-tap like (must set, never un-like). Find off-by-ones, timezone/DST issues,
   resurrection bugs in merges.
3. **Dead / unreachable code.** The redesign likely orphaned things: `bottomNav`, `likeScale`,
   `actionIcon()`, the `.categories`/`.practice` sheet cases, `CategoriesView`/`DecksView`,
   `practiceGamesRemaining`/`recordPracticeGame`, deprecated `UserProfile` fields. List what's now
   dead and safe to delete.
4. **Wiring / connectivity.** Every button reaches a destination; every sheet presents and gets the
   env objects it needs (note `.sheet` env inheritance assumptions); no orphaned `@State`; deep
   links (`verbum://word/<uuid>`), Spotlight, and notification taps all resolve.
5. **SwiftUI & memory.** Retain cycles (timers, closures, `[weak self]`), `@StateObject` vs
   `@ObservedObject`, unnecessary re-renders on the feed, `ImageRenderer` usage in the share card.
6. **Data integrity.** Codable back-compat for `UserProfile` (new fields decode from old data),
   read-only DB invariants, FTS query escaping, the merge functions' idempotency.
7. **Performance.** Feed scroll (per-swipe work), startup (DB open + first render), FTS, the
   placeholder like-count hashing, any main-thread blocking.
8. **Accessibility / HIG / Dynamic Type / Reduce Motion.** VoiceOver on the gesture feed, the
   double-tap like for VO users, Dynamic Type clipping, Reduce Motion gating of the heart burst /
   confetti.
9. **Security & privacy.** Hardcoded secrets, ATS/`http://`, SQL injection (GRDB is parameterized —
   confirm), deep-link validation, Keychain usage, the dormant backend's CloudKit/GameKit code,
   `PrivacyInfo.xcprivacy` accuracy, `NSPhotoLibraryAddUsageDescription` presence (Save Image),
   any PII in logs.
10. **App Store readiness.** Stubs/SiwA correctly hidden behind flags; subscription/paywall
    compliance (restore, terms, privacy, auto-renew disclosure); account-deletion reachability;
    placeholder `appStoreID`; the privacy URL (currently 404 — `docs/privacy.html` is ready to host).
11. **Dormant backend (`VERBUM_BACKEND`).** Set the flag mentally/really and verify the GameKit
    (`GKLeaderboard.submitScore`, `loadEntries`) and CloudKit (`CKQuery`, `records(matching:)`,
    `userRecordID()`) calls compile and are API-correct on iOS 16+. Note the provisioning the app
    needs (see `docs/BACKEND.md`).
12. **Localization.** en/de/uk parity for any new user-facing strings added in the redesign
    (NSLocalizedString coverage), and that new English literals are at least non-breaking.
13. **Anything a veteran would catch** that the above missed — taste, edge cases, footguns, a
    better way to structure something fragile.

## Output format
- **Executive summary** (5–8 bullets) + a one-line verdict on shippability and on "does it compile."
- Findings grouped by area, each: **[severity P0–P3] `file:line` — what / why it bites / fix.**
- A short **dead-code list** (safe to delete) and a **"fix before submission"** checklist.
- Don't hedge. If you're unsure, say what you'd run to confirm.
