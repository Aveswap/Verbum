# Verbum — App Store Connect listing & submission pack

Copy-paste ready. Character counts noted against Apple's limits. English (primary). Add DE/UK
localizations later if you ship those UI languages.

---

## App Name  (max 30)
```
Verbum: Beautiful Rare Words
```
(28 chars)

Alternatives:
- `Verbum — Rare Beautiful Words` (29)
- `Verbum: Word of the Day` (23)

## Subtitle  (max 30)
```
Collect rare, beautiful words
```
(29 chars)

Alternatives:
- `Rare words for what you feel` (28)
- `A daily feed of rare words` (26)

## Keywords  (max 100, comma-separated, NO spaces after commas)
```
vocabulary,word of the day,rare words,dictionary,etymology,thesaurus,english,language,lexicon
```
(93 chars) — don't repeat the app name or words already in the title/subtitle; Apple indexes those
separately.

## Promotional Text  (max 170 — editable anytime without review)
```
Now with a Dynamic Island challenge timer and a daily word pulled from your own collection. 974 rare, beautiful words — and the library keeps growing.
```
(149 chars)

---

## Description  (max 4000)

```
Some feelings don't have a word — until they do.

Verbum is a beautiful, swipeable feed of the rarest, most gorgeous words in the English language. Petrichor. Gloaming. Susurrus. Hiraeth. Each one is a tiny discovery — the kind of word you screenshot and never forget.

Swipe through a curated collection of 974 dictionary-verified words (and growing). Tap to hear it spoken, read where it came from, and see how it's used. Found one that's yours? Save it to your personal Lexicon and write down why it stuck.

This isn't a textbook. It's a 60-second daily ritual that makes the language feel alive again.

— WHAT YOU GET —

• A TikTok-style feed of rare, beautiful words — definition, pronunciation, example, and the story behind each one
• Your own Lexicon: collect the words that move you and add a personal note to each
• A daily notification that brings one of YOUR saved words back, right before you'd forget it
• Optional Practice: quick challenges (Perfection, Rush, Sprint) that turn remembering into a game, with a live timer in the Dynamic Island
• Spaced-repetition under the hood, so the words you collect actually stick
• Dark, distraction-free design built for the words

— BEAUTIFUL WORDS, REAL DICTIONARIES —

Every word is a genuine headword verified against the Oxford English Dictionary, Merriam-Webster, or Collins. No invented "internet words" — just the real, forgotten treasures of English (plus a few untranslatable gems like hygge and saudade).

— FREE & PREMIUM —

Start with 50 words completely free. Verbum Premium unlocks the entire growing collection and all Practice modes:

• Monthly and yearly subscriptions, or a one-time Lifetime unlock
• New words are added regularly — your collection keeps growing
• Cancel anytime

Payment is charged to your Apple ID at confirmation of purchase. Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period; your account is charged for renewal within 24 hours before the period ends. Manage or cancel in your Apple ID Account Settings.

Privacy Policy: https://verbum.app/privacy
Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

Collect the words for the feelings you couldn't name.
```

## What's New (v1.0 release notes)
```
Welcome to Verbum — a daily feed of the most beautiful, rare words in English.

• Swipe a curated feed of 974 dictionary-verified words
• Save the ones you love to your personal Lexicon and add a note
• A daily reminder brings your own saved words back before you forget them
• Practice challenges with a live timer in the Dynamic Island
• Hear every word spoken, with its etymology and an example

Thanks for collecting words with us. New words are added regularly.
```

---

## App Privacy (nutrition label, App Store Connect → App Privacy)

**This shipping build is fully local** — Sign in with Apple, CloudKit sync, Game Center, and the
cross-user social backend are all OFF. Nothing is transmitted off-device and linked to the user.

**Answer: "Data Not Collected."**
- Do you or your third-party partners collect data from this app? → **No.**
- Rationale: the word database is bundled and read-only; all user state (saved words, notes,
  streaks, settings) lives only on-device in UserDefaults; purchases are handled by Apple's StoreKit
  (Apple, not you, processes them); analytics is local `os.Logger` only (never sent off device).

⚠️ **The day you flip the backend / Sign in with Apple ON**, update this to declare what you then
collect (e.g. Identifiers → User ID, Contact Info → Email Address, Usage Data → Product Interaction,
Purchases) — all "linked to identity, not used for tracking." Your `PrivacyInfo.xcprivacy` already
over-declares these (the safe direction), so only the nutrition label needs updating then.

---

## Age Rating questionnaire (App Store Connect → Age Rating) → target 4+

Answer **None / No** to essentially everything:
- Cartoon/Fantasy Violence, Realistic Violence, Sexual Content/Nudity, Profanity/Crude Humor,
  Alcohol/Tobacco/Drugs, Mature/Suggestive Themes, Horror, Gambling (simulated or real),
  Contests → **None.**
- Medical/Treatment Information → **No.**
- Unrestricted Web Access → **No** (the only outbound links are the privacy policy, Apple EULA,
  Instagram, and the App Store — no in-app browser).
- User-Generated Content / does the app contain UGC that's shared with others → **No** (notes are
  private and on-device; the social/likes backend is OFF).
- In-app controls / parental gate needed → **No.**
- → Expected rating: **4+.**

⚠️ If you ever turn on the cross-user social features, the UGC answers change and you take on
UGC obligations (filtering, reporting, blocking) and likely a higher rating.

---

## App Review Information → Notes for Reviewer

```
Verbum is a vocabulary app — a feed of rare English words you can collect and learn.

NO LOGIN: The app requires no account and no login. Sign in with Apple, iCloud sync, and Game Center are intentionally disabled in this version; there are no dead/"coming soon" buttons for them. No demo account is needed — all features are reachable on first launch.

FREE vs PREMIUM: 50 words are free. Verbum Premium (auto-renewable monthly/yearly, or a one-time Lifetime non-consumable) unlocks the full, regularly-updated collection and the Practice modes. The paywall (Profile → Go Premium) shows price, period, the full auto-renewal disclosure, Restore Purchases, and links to the Privacy Policy and Apple's Standard EULA.

LIVE ACTIVITY: The "Rush" practice challenge offers an optional Live Activity. It is started only by an explicit user action (starting a Rush round), is strictly time-boxed (a 60-second challenge), shows a live countdown + score in the Dynamic Island / Lock Screen, and ends immediately when the round finishes — well within ActivityKit's intended use.

NETWORK: The app is fully on-device. StoreKit is the only system service it talks to. No user data leaves the device.
```

### Export Compliance
`ITSAppUsesNonExemptEncryption = false` is set in Info.plist (only standard HTTPS/OS crypto) → no
"Missing Compliance" prompt, no encryption documentation upload required.

### License Agreement
App Store Connect → App Information → License Agreement → **Standard Apple EULA** (the in-app Terms
link already points to Apple's standard EULA URL).
```
