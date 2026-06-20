# Cross-user backend — how to turn it on

The app ships with the backend **dormant**: a no-op seam is compiled, the heavy GameKit/CloudKit
code is excluded, and the UI just hides cross-user counts/medals. Nothing here runs or is testable
from a Command-Line-Tools environment — it needs a real Xcode build + Apple Developer provisioning.

Two features:
- **Leaderboards + medals** (Perfection / Rush / Sprint) → **GameCenter** (Apple hosts the ranking).
- **Cross-user likes** ("N people loved this") → **CloudKit public database**.

## Code layout (already in the repo, dormant)
- `Verbum/Core/Data/Backend.swift` — IDs/config + the `Medal` enum.
- `Verbum/Core/Data/LeaderboardService.swift` — `Leaderboards.service` (no-op default; real
  `GameCenterLeaderboardService` behind `#if VERBUM_BACKEND`).
- `Verbum/Core/Data/PublicLikesService.swift` — `PublicLikes.service` (no-op default; real
  `CloudKitLikesService` behind `#if VERBUM_BACKEND`).
- Wired: double-tap like → `PublicLikes.service.like`; challenge finish → `Leaderboards.service.submit`
  + medal badge; word detail → "N people loved this".

## To enable

### 1. Flip the compilation flag
In `project.yml`, add `VERBUM_BACKEND` to the app target's active compilation conditions, e.g.:
```yaml
    settings:
      base:
        SWIFT_ACTIVE_COMPILATION_CONDITIONS: "$(inherited) VERBUM_BACKEND"
```
Then `xcodegen generate`. (Or scope it to Release only.) This links in the GameKit/CloudKit code.

### 2. GameCenter (leaderboards + medals)
- Xcode → Signing & Capabilities → add **Game Center**.
- App Store Connect → your app → Game Center → create **3 leaderboards**, with IDs matching
  `Backend.leaderboardID(for:)`:
  - `com.verbum.app.perfection`
  - `com.verbum.app.rush`
  - `com.verbum.app.sprint`
  - Score format: integer, higher is better.
- Restore the real `GameCenterService` (authenticate the local player) — it currently authenticates
  via the stub; the `.original` is in `_LocalDev-Disabled/`. Medals derive automatically from the
  top-3 global rank.

### 3. CloudKit public likes
- Xcode → Signing & Capabilities → **iCloud → CloudKit** with the app's container.
- CloudKit Dashboard → **Public Database** → add record type **`WordLike`** with a queryable
  `String` field **`wordID`** (mark it Queryable so the count query works; add an index).
- Likes write to the public DB (one record per user per word, idempotent); the count is a query.
  At scale, replace the fetch-count with a cached counter — see the note in `PublicLikesService`.

### 4. Entitlements
Add the matching entitlements to `Verbum/Verbum.entitlements` (Game Center + iCloud/CloudKit
container) — these are currently omitted on purpose (see the project.yml note about stubbed
services).

## ⚠️ Reality checks
- **Untested from this repo's CLT environment.** Verify the GameKit/CloudKit API calls on the first
  real build (signatures noted in the source).
- **Premature before you have users** (the councils flagged this): a leaderboard with no players is
  empty, and "likes from others" needs an audience. Ideally enable after the D7 cohort exists.
