# Widget + Apple Watch — Xcode Target Setup

All the Swift code already lives in the repo. The only missing pieces are the
two Xcode targets and the App Group capability — both have to be added through
Xcode's UI because they touch `project.pbxproj` in ways the file system can't
safely synthesize.

This is a one-time setup. After it's done, both extensions will read the
shared timeline written by the main app on every launch and state change
(see [VerbumApp.swift](../Verbum/App/VerbumApp.swift) and
[SharedTimelinePublisher.swift](../Verbum/Core/Data/SharedTimelinePublisher.swift)).

---

## 0. Prerequisite — App Group

The App ID needs an App Group with identifier **`group.com.verbum.app`**.

1. Open the Apple Developer portal → Certificates, Identifiers & Profiles.
2. Identifiers → click the Verbum App ID → enable **App Groups** capability →
   pick (or create) **`group.com.verbum.app`**.
3. Xcode → Verbum target → **Signing & Capabilities** → confirm App Groups
   capability is present and `group.com.verbum.app` is checked. The main app's
   [Verbum.entitlements](../Verbum/Verbum.entitlements) already declares it.

Same App Group goes on the two extension targets below.

---

## 1. Word of the Day Widget target

The Swift files live in [`VerbumWidget/`](../VerbumWidget/):

- `VerbumWidgetBundle.swift` — `@main` entry, lists widgets
- `WordOfDayWidget.swift` — widget configuration + supported families
- `WordOfDayProvider.swift` — `TimelineProvider`, reads from `SharedWordStore`
- `WordOfDayEntryView.swift` — small / medium / large SwiftUI views
- `VerbumWidget.entitlements` — App Group declaration

### Steps in Xcode

1. **File → New → Target → Widget Extension**.
2. Product Name: `VerbumWidget`. Bundle ID: `com.verbum.app.VerbumWidget`.
   Embed in Application: **Verbum**. Include Configuration Intent: **no** (we
   use a static timeline).
3. Xcode generates a starter `VerbumWidget.swift`. **Delete** it and the
   starter `Info.plist` if it creates one.
4. In Project Navigator, right-click the new `VerbumWidget` group →
   **Add Files to "Verbum"…** → pick the four `.swift` files from the
   `VerbumWidget/` folder on disk. Make sure target membership = `VerbumWidget`
   (NOT the main app).
5. Also add to `VerbumWidget` target membership:
   - [`Verbum/Core/Data/SharedWordStore.swift`](../Verbum/Core/Data/SharedWordStore.swift)
     ✓ ALSO check the `VerbumWidget` target — it's shared source.
6. **Signing & Capabilities** for `VerbumWidget` target:
   - Set team / signing same as main app
   - Click **+ Capability** → **App Groups** → check `group.com.verbum.app`
   - Replace the generated `VerbumWidgetExtension.entitlements` with the one
     from the repo (`VerbumWidget/VerbumWidget.entitlements`), or just edit
     the generated file to match
7. Build & run the `VerbumWidget` scheme on the simulator → long-press the
   home screen → **+** → search "Verbum" → add the widget.

### What you should see

- After launching the main app at least once, the widget renders today's word
  (e.g. `resilient`) with phonetic, part of speech, and a streak pill.
- The medium / large families also show the definition and, when available,
  the Ukrainian translation.
- For a free user near the end of their 50-word pool, the large family shows
  an orange "N free words left" hint.

### Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Widget shows "Open Verbum to set up your daily word" | Main app hasn't been launched yet, or App Group capability isn't on the main app. Verify [VerbumApp.swift](../Verbum/App/VerbumApp.swift) calls `SharedTimelinePublisher.refresh` in `onAppear`. |
| Widget never updates | `WidgetCenter.shared.reloadAllTimelines()` only nudges; iOS still rate-limits. Quick way to force-refresh in dev: edit the widget on the home screen (remove + re-add). |
| Build error "Cannot find SharedWordStore" | The file isn't in the `VerbumWidget` target. Fix the target membership checkboxes. |

---

## 2. Apple Watch target

The Swift files live in [`VerbumWatch Watch App/`](../VerbumWatch%20Watch%20App/):

- `VerbumWatchApp.swift` — `@main` entry
- `WatchHomeView.swift` — single-screen glance with today + tomorrow card
- `VerbumWatch.entitlements` — App Group declaration

### Steps in Xcode

1. **File → New → Target → Watch App**.
2. Product Name: `VerbumWatch`. Interface: **SwiftUI**. Bundle ID:
   `com.verbum.app.watchkitapp`. Companion: **Verbum**.
3. Xcode creates `VerbumWatch Watch App` group. Delete the generated
   `ContentView.swift` and `VerbumWatchApp.swift` placeholders.
4. Right-click the new group → **Add Files to "Verbum"…** → pick
   `VerbumWatchApp.swift` and `WatchHomeView.swift` from
   `VerbumWatch Watch App/` on disk. Target membership = `VerbumWatch Watch App`.
5. Also add to the Watch app target membership:
   - [`Verbum/Core/Data/SharedWordStore.swift`](../Verbum/Core/Data/SharedWordStore.swift)
     ✓ ALSO check `VerbumWatch Watch App` membership
6. **Signing & Capabilities** for `VerbumWatch Watch App` target:
   - Set team / signing same as main app
   - **+ Capability** → **App Groups** → check `group.com.verbum.app`

### What you should see

- Pair an Apple Watch simulator with the iPhone simulator.
- Launch the main app on iPhone first — it publishes the timeline.
- Launch `VerbumWatch` on the Watch simulator → glance shows today's word,
  phonetic, part of speech, definition, optional UA translation, plus a 🔥
  streak pill in the corner.
- Tap "Show tomorrow" → blurred tomorrow card appears below ("Tap to reveal
  at midnight").

### Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Watch shows "Open Verbum on your iPhone to sync today's word" | Main app hasn't run; or App Group not enabled on either side. Re-run the main app first. |
| Two duplicate `extension Color { init(hex:) }` errors | The Watch target picked up the main app's `Colors.swift`. Make sure `Colors.swift` is **NOT** in the Watch target. The Watch app has its own local `hex` helper inside `WatchHomeView.swift`. |
| Watch app crashes on launch | UserDefaults suite name typo. Confirm `SharedWordStore.appGroupID == "group.com.verbum.app"` and the entitlement matches. |

---

## 3. Verification

After both targets are set up:

```bash
# Verify entitlements
plutil -p Verbum/Verbum.entitlements | grep -A1 application-groups
plutil -p VerbumWidget/VerbumWidget.entitlements | grep -A1 application-groups
plutil -p "VerbumWatch Watch App/VerbumWatch.entitlements" | grep -A1 application-groups
# All three should print group.com.verbum.app

# Verify shared source files are accessible
ls Verbum/Core/Data/SharedWordStore.swift Verbum/Core/Data/SharedTimelinePublisher.swift
```

In the running app:

1. Launch main app → swipe a couple of words to make sure
   `wordsLearnedToday` snapshot value is non-zero
2. Pull down notification center → check the widget on lock screen
3. Apple Watch glance shows the same word as today's feed entry

That's it. Future word generation, level changes, and premium upgrades all
flow into the widget and watch automatically through the existing
`onChange` hooks in `VerbumApp.swift`.

---

## Architecture recap

```
                    ┌──────────────────────────────┐
                    │  Verbum (main app, iOS)      │
                    │  • UserProfileStore          │
                    │  • WordRepository            │
                    │  • SubscriptionManager       │
                    └──────────────┬───────────────┘
                                   │ on launch + onChange
                                   ▼
                ┌─────────────────────────────────────┐
                │  SharedTimelinePublisher.refresh()  │
                └──────────────┬──────────────────────┘
                               │ encode
                               ▼
        ┌────────────────────────────────────────────────┐
        │   App Group UserDefaults: group.com.verbum.app │
        │   • timeline_v1   (14 × DailyWord)             │
        │   • snapshot_v1   (Snapshot)                   │
        │   • writtenAt_v1  (Date)                       │
        └────┬────────────────────────────────────┬──────┘
             │                                    │
             ▼                                    ▼
    ┌─────────────────┐                  ┌────────────────────┐
    │ VerbumWidget    │                  │ VerbumWatch        │
    │ (iOS Widget)    │                  │ (watchOS app)      │
    │ • Provider      │                  │ • WatchHomeView    │
    │ • EntryView     │                  │                    │
    └─────────────────┘                  └────────────────────┘
```

No network, no XPC, no WatchConnectivity. iOS / watchOS gives each extension
the same UserDefaults suite as the host app via the App Group capability.
