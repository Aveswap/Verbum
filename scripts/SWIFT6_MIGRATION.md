# Swift 6 Strict-Concurrency Migration — step-by-step (do this in Xcode)

This is a **build-driven** migration: you flip one build setting up a notch, hit ⌘B,
fix what the compiler complains about, and repeat. Do it on a branch and commit after each
green build so you can always step back.

```bash
git checkout -b swift6-migration
```

Audit basis: `456verbum_audit_report.md` → "Архітектурні покращення" #1, and the code
review's ARCH #14. None of this changes behaviour — it's compile-time safety against data
races. The app already runs without it, so there's no rush and no user-visible change.

The build setting is **Build Settings → Swift Compiler - Language → Strict Concurrency
Checking**, values `Minimal` → `Targeted` → `Complete`. Migrate in that order.

---

## Step 0 — Pre-req quick win (safe, do first)

**File: `Features/WordDetail/WordDetailViewModel.swift`** — it's the only `ObservableObject`
without `@MainActor`. Add it for consistency with every other view-model:

```swift
@MainActor
class WordDetailViewModel: ObservableObject {
```

⌘B. Should stay green. Commit: `chore: @MainActor on WordDetailViewModel`.

---

## Step 1 — Set checking to "Targeted", build, read the warnings

Set **Strict Concurrency Checking = Targeted** for the **Verbum** target. ⌘B.

`Targeted` only checks code that already opts into concurrency (`@MainActor`, `async`,
`Task`, `Sendable`). You'll get a manageable list of warnings, mostly: "capture of
non-Sendable type … in a `@Sendable` closure" and "non-Sendable type … crossing actor
boundary". Work through them file by file below.

---

## Step 2 — Make the shared singletons Sendable

These are plain classes/enums reached from more than one thread. Each needs an explicit
concurrency story. Recommended choice per type is **bolded**.

### 2a. `Core/Data/WordDatabase.swift`
Reached from the main actor (`WordRepository.load`) **and** background (`seedInBackground`,
`SpotlightIndexer`, the `Task.detached` reads in `SearchView` / `WordCardView`).

- GRDB's `DatabaseQueue` is already thread-safe, and `dbQueue` is only ever **assigned** on
  the main thread (init, `openIfExists`, the `seedInBackground` completion). Reads are safe.
- **Recommended:** declare it `@unchecked Sendable` and document the invariant:
  ```swift
  /// @unchecked Sendable: GRDB's DatabaseQueue is thread-safe; `dbQueue` is only assigned on
  /// the main thread, all other access is read-only. See seedInBackground()/openIfExists().
  final class WordDatabase: @unchecked Sendable {
  ```
- Alternative (cleaner but ripples everywhere): convert to `actor`. Rejected for now — it
  forces `await` on the many synchronous call sites (`WordRepository.load`, `translation(...)`).

### 2b. `Core/Data/TranslationStore.swift`
Loads `translations.json` into `private var cache` during `init`, then it's read-only. Because
`cache` is a stored `var`, pure `Sendable` won't apply.
- **Recommended:** `final class TranslationStore: @unchecked Sendable { … }` with a comment
  that `cache` is written only in `init` and read-only thereafter.
- Also mark the nested value type Sendable (free, it's `String`/`String?`):
  `struct Translation: Sendable` in `WordDatabase.swift`.
- (Optional cleaner variant: build the dictionary in a local `let` inside `init` and assign
  once to a `let cache`; then plain `Sendable` works.)

### 2c. `Core/Components/SoundManager.swift` — real data race to fix
`playCorrectChime()` dispatches to `DispatchQueue.global` and then `scheduleNote()` mutates
`poolIndex` and starts the engine **off the main thread**, while the manager is also touched
from the main thread. Fix the isolation:

- **Recommended:** mark the class `@MainActor` and replace the global-queue note delays with
  main-actor `Task`s:
  ```swift
  @MainActor
  final class SoundManager {
      …
      func playCorrectChime() {
          guard soundEnabled else { return }
          let notes: [(freq: Double, delay: Double)] = [ (523.25,0), (659.25,0.12), (783.99,0.24) ]
          for note in notes {
              Task { @MainActor in
                  try? await Task.sleep(nanoseconds: UInt64(note.delay * 1_000_000_000))
                  self.scheduleNote(frequency: note.freq, duration: 0.30, amplitude: 0.35)
              }
          }
      }
  }
  ```
  Buffer generation in `scheduleNote` is light; running it on the main actor is fine.
  Callers (`SoundManager.shared.playCorrectChime()`) already run on the main actor, so no
  call-site changes.

### 2d. `Core/Components/HapticManager.swift` — manually-synchronized statics
It guards `_engine` / `_engineRunning` with an `NSRecursiveLock`, which is correct but the
compiler can't prove it. Use the Swift 6 escape hatch for hand-synchronized state:

```swift
nonisolated(unsafe) private static var _engine: CHHapticEngine?
nonisolated(unsafe) private static var _engineRunning = false
```

Keep the lock exactly as-is — `nonisolated(unsafe)` just tells the compiler "I've handled
the synchronisation myself."

### 2e. `Core/Data/SharedWordStore.swift`, `Core/Data/KeychainHelper.swift`, `Core/AppInfo.swift`
Stateless enums / `UserDefaults`-backed computed accessors — these should compile clean. If
`SharedWordStore` flags its `static var` computed properties, they're fine (no stored mutable
state); no change expected.

Commit after Step 2: `refactor: Sendable annotations on shared singletons`.

---

## Step 3 — Verify the URLSession delegate path
`Core/Data/DatabaseDownloadManager.swift` already does this correctly: the three
`nonisolated func urlSession(...)` delegate methods hop back with `Task { @MainActor in … }`.
Under `Targeted` this should be clean. If `complete` later flags the captured `location: URL`
(URL is Sendable) or `self`, you're fine — `self` is `@MainActor` and hops are explicit.

---

## Step 4 — DispatchQueue.main.asyncAfter in views
Most are inside SwiftUI views (`ProfileSetupViews`, `DecksView`, `NotificationSettingsView`,
the toast timers in `WordFeedView`). Closures dispatched to `DispatchQueue.main` are not
automatically `@MainActor`-isolated, so `complete` may warn about touching `@State`/actor
state inside them.

- Lowest-risk fix per site: replace
  `DispatchQueue.main.asyncAfter(deadline: .now() + d) { … }`
  with
  `Task { @MainActor in try? await Task.sleep(nanoseconds: UInt64(d * 1e9)); … }`.
- You already did this for the feed banner/hint timers — repeat the pattern for the onboarding
  auto-advance delays and the Decks→Categories hop as warnings appear. Don't pre-emptively
  change them; let the compiler point.

Commit: `refactor: main-actor Task delays instead of asyncAfter`.

---

## Step 5 — Flip to "Complete", build, mop up
Set **Strict Concurrency Checking = Complete**. ⌘B. Remaining warnings are usually:
- A closure passed to a non-isolated API capturing `@MainActor` state → wrap its body in
  `Task { @MainActor in … }` or mark the closure `@Sendable` and capture a copy.
- `Codable`/model types crossing boundaries — `Word`, `UserProfile`, `WordReview`, `WordDeck`
  are value types of Sendable members, so add `: Sendable` to them if asked (free, safe).
- GRDB types: GRDB 6.29 is concurrency-aware; if a `Row`/`Database` closure warns, keep the
  work inside the `dbQueue.read/write` block (don't capture `db` out of it).

When `Complete` is green, optionally set the **Swift Language Version = Swift 6** (Build
Settings → Swift Compiler - Language) for the final enforcement. Build once more.

Commit: `feat: Swift 6 strict concurrency (complete) enabled`.

---

## Step 6 — Smoke test on simulator
Concurrency bugs hide at runtime. After it compiles, run and exercise:
- Cold launch (first-run bundled-DB seed path), swipe feed, open a word, run each practice
  game, trigger a daily-goal celebration (sound + haptics → SoundManager/HapticManager),
  search, Spotlight-open, background→foreground (CloudKit pull), purchase in StoreKit sandbox.
- Watch the Xcode console for purple **Thread Sanitizer** / main-thread-checker warnings
  (enable Thread Sanitizer in the scheme's Diagnostics for one run).

---

## Order summary (commit after each)
1. `@MainActor` on `WordDetailViewModel`
2. Strict Concurrency = **Targeted**, build
3. Sendable on `WordDatabase`, `TranslationStore`; `@MainActor` `SoundManager`;
   `nonisolated(unsafe)` `HapticManager` statics
4. Convert remaining `DispatchQueue.main.asyncAfter` → main-actor `Task`
5. Strict Concurrency = **Complete** (then Swift Language Version = 6), mop up
6. Simulator smoke test with Thread Sanitizer

---

## Appendix — Dependency Injection (audit rec #2), separate effort
Not required for Swift 6 and not user-visible; improves testability. Sketch only:
- Define protocols for the singletons you want to fake in tests, e.g.
  `protocol WordProviding { var all: [Word] { get }; func words(matching: String) -> [Word] }`
  and conform `WordRepository`.
- Inject via SwiftUI `Environment` (a custom `EnvironmentKey`) or pass into initializers,
  instead of reaching for `.shared` inside views/view-models.
- Do this incrementally, one collaborator at a time, only where you actually want test
  coverage — a full big-bang de-singletoning isn't worth it for this codebase size.
```
