# Testing Premium in the Simulator

A StoreKit Configuration file (`Verbum/Verbum.storekit`) ships in the repo with all three products preconfigured. Connect it to the run scheme once — afterwards every simulator launch shows the real paywall, lets you buy, and unlocks every gate in the app.

---

## One-time setup (Xcode)

1. Open **Verbum.xcodeproj** in Xcode.
2. **Add the file to the project** (it lives at `Verbum/Verbum.storekit`):
   - In the Project Navigator, right-click `Verbum` → **Add Files to "Verbum"…**
   - Pick `Verbum.storekit`, untick "Copy items if needed", target = **Verbum**.
3. **Wire it into the scheme**:
   - Product menu → **Scheme** → **Edit Scheme…** (or ⌘<)
   - Select **Run** in the left sidebar, then the **Options** tab
   - Find **StoreKit Configuration** → choose `Verbum.storekit`
   - Close.

You only do this once. The setting is per-developer (stored under `xcuserdata/`).

---

## What's in the .storekit file

| Product ID    | Type                  | Display Price | Trial      |
|---------------|-----------------------|---------------|------------|
| `pro_monthly` | Auto-renewable        | $4.99 / month | none       |
| `pro_yearly`  | Auto-renewable        | $24.99 / year | 1 week free |
| `pro_lifetime`| Non-consumable        | $59.99 once   | n/a        |

The yearly tier intentionally includes a 1-week free trial so the dynamic CTA in `PremiumSheet.swift` ("Start Free Trial" / "Subscribe Now" / "Get Lifetime Access") can be exercised.

---

## What to test

### Happy path
1. Run the app in the simulator.
2. Onboarding → swipe a locked card → premium sheet appears.
3. Tap a plan → **Confirm** in the Apple sandbox dialog.
4. Watch:
   - The premium sheet auto-dismisses.
   - Profile shows `premiumActiveCard` ("Verbum Premium ✓").
   - Feed: previously-blurred Intermediate/Expert cards become readable.
   - Practice menu: the "X of 3 sessions left today" banner disappears.
   - Categories: premium buckets (Tech & Science / Arts & Ideas / Society) unlock.
   - WordDetailView: opens for any word, no premium gate.

### Restore
1. **Settings → Restore Purchases**.
2. With a previous test purchase recorded, `isPro` should flip back to true within ~1 second.

### Expire / cancel
1. Xcode menu → **Debug** → **StoreKit** → **Manage Transactions…**
2. Find the active `pro_monthly` or `pro_yearly` transaction.
3. **Delete** it (or **Refund** to simulate a refund).
4. Relaunch the app → previously-pro user is back to free; locked cards reblur.

### Free-trial behaviour
1. Buy `pro_yearly` from a clean state. The sandbox starts the 1-week trial.
2. Open the manage transactions sheet and you'll see "introductory offer" until the trial expires.
3. Time-warp by changing the **Subscription Renewal Rate** in StoreKit settings:
   - Debug → StoreKit → **Time Rate** → "Every 1 minute is 1 day" (or similar)
   - Wait a minute; the trial transitions to paid.

### Failure modes
- Set Debug → StoreKit → **Storefront** to a country without the product → app shows the fallback price strings from `PremiumSheet.productRows`.
- Toggle network offline → `loadProducts()` returns empty; UI gracefully shows fallback prices.

---

## Common gotchas

| Symptom | Fix |
|---------|-----|
| `subscriptions.products.isEmpty` and only fallback rows show | StoreKit Configuration not selected in the scheme. Re-do step 3 above. |
| Buying doesn't unlock anything | Check that `SubscriptionManager.refreshEntitlements()` is being called after the transaction (it is, in `purchase()`). |
| "Already subscribed" appears immediately on a fresh install | Delete the app's container: Simulator → **Device** → **Erase All Content and Settings**. |
| Yearly free trial doesn't activate | The introductoryOffer block is only honored when no prior transaction exists for the product. Erase content first. |
| Apple ID sign-in keeps prompting | Set Settings → Developer → **StoreKit Testing** → **Account holder name** to anything in the simulator settings. |

---

## Reverting to App Store Connect testing

When you want to test with real sandbox testers instead of the local config:

1. Edit Scheme → Run → Options → **StoreKit Configuration** → **None**.
2. Run on a physical device signed into a sandbox tester Apple ID (create one in App Store Connect → Users & Access → Sandbox).
3. Purchases now hit App Store Connect's sandbox environment.
