# LLM Council Transcript — Verbum viability audit

**Date:** 2026-06-19
**Question:** Full audit of the app/code/bugs/features + will real people use and pay for Verbum, and if not, what to fix?

---

## Framed question (given to all advisors)

Verbum is a finished-but-unreleased iOS app (SwiftUI, iOS 16+, dark-mode only). Decide: will real people download, keep using, and pay for it — and if not, what must change?

- **What it is:** a vocabulary app built around RARE, beautiful "wow" English words — 434 curated dictionary-verified headwords (petrichor, threnody, susurrus, komorebi). Hook is delight, not SAT prep. Core UX is a vertical TikTok-style swipe feed of word cards (definition, IPA, example, etymology, tap-to-pronounce TTS). Engagement: daily streaks + freezes, daily goal + confetti, 5-word batch quizzes, FSRS spaced repetition, daily notifications, Spotlight, like/bookmark, decks, quarterly badges.
- **Monetization:** soft paywall — 50 words free, the other ~384 (+4 premium categories) behind a monthly/yearly/lifetime subscription (StoreKit 2).
- **Current state:** CloudKit sync, Sign in with Apple, Game Center STUBBED OUT; widget removed; privacy URL 404s; no App Store ID; not submitted. Solo dev, no audience/marketing/budget, no analytics. Passed a senior code audit (low crash surface). Crowded market.

---

## Advisor responses (de-anonymized)

**The Contrarian:** 50 free words is a brutal paywall for an unknown brand — users burn the quota in one sitting before any habit forms; conversion near zero. "Wow words" is a one-night-stand category, not a habit: petrichor delights once, nothing pulls users back on day 30. 434 words is a hard content ceiling. The FSRS/streak/quiz machinery contradicts the "delight not prep" pitch. Services stubbed + no analytics = can't even measure retention. Fatal question: who wakes up wanting this, and why do they return on day 30?

**The First-Principles Thinker:** You assumed "vocabulary app" is the category. It isn't — the job the cards do is the same as a coffee-table book or poetry account: a 10-second aesthetic hit that makes the user feel refined. The learning machinery (FSRS/quizzes/streaks) serves a job nobody hired you for; it dilutes the vibe and invites an Anki comparison you lose. The feed IS the product. 434 words isn't a product, it's a launch week; the curated moat is also the churn cliff. The paywall is backwards — charge for more beauty forever, and content must never end. Decide first: can you generate an endless stream of wow words without diluting curation? If no, it's an exquisite demo — ship it free.

**The Expansionist:** The wow-word feed isn't a feature — it's content IP. The cards are screenshot-bait; the core loop doubles as TikTok/Reels content, so the product IS the top-of-funnel. Build one-tap branded share-export and every user becomes a distributor. WTP is high because this is identity, not study (like Calm/Moleskine); the lifetime tier becomes a gift purchase for a gifting niche nobody serves. Expand via themed packs (grief words, nautical words), seasonal drops, collabs — each a new SKU. Don't bury the moat behind a 50-word paywall; give more away to feed the funnel, charge for collection/status. Ship the share-export first.

**The Outsider:** The pitch is gorgeous — "TikTok for beautiful words," I'd download it on a slow Sunday. But I'd download, not keep using: swiping pretty words is a mood, not a habit; 20 minutes and I've had my dopamine. The quiz/streak machinery is homework bolted onto a vibe. Two audiences fight: delight-seekers don't want quizzes; learners want useful words, not komorebi (which isn't even English). I definitely wouldn't pay monthly to look at words I can Google. Lifetime maybe, monthly never. Fix: pick ONE job — delight (free + tip jar, win on shareability) or paid (then you need a daily reason to return, and beautiful words alone isn't it).

**The Executor:** You cannot know retention from the armchair — ship the smallest legal build. Before submission (all small): live privacy URL (Apple rejects without it), App Store ID + TestFlight, one analytics SDK (TelemetryDeck/PostHog — highest-leverage; without it you're blind), 7-day trial. Waste of time now: CloudKit, Sign in with Apple, Game Center, widget. Fastest signal this week: TestFlight + 3 posts (r/EnglishLearning, a "beautiful words" TikTok of the feed, a writing community). Get 100 installs, watch day-7 retention + paywall-view rate. If 100 strangers won't return on day 2 for free, no polish saves it.

---

## Peer-review consensus (5 reviewers, blind)

- **Strongest: the Executor — unanimous.** Only response that refuses to theorize and converts the question into a cheap, falsifiable experiment (ship → instrument → 100 installs → read day-7 retention).
- **Biggest blind spot: the Expansionist — unanimous.** Its content-IP/infinite-packs thesis assumes a solo dev can supply an endless stream of genuinely-wow, dictionary-valid words without diluting curation; it bets everything on an untested virality loop.
- **What all five missed (caught in review):**
  1. **The moat and the churn cliff are the same unsolved problem** — can one solo dev source thousands more wow words (foreign cap ~15) without dilution? Possibly unsolvable.
  2. **Free substitutes** — the exact words are free everywhere (r/wordoftheday, dictionaries, ChatGPT, word TikToks). The paywall competes with $0, so WTP may be structurally zero.
  3. **Solo-dev distribution bottleneck** — every growth thesis assumes one person can be a daily content + marketing engine.
  4. **Sunk-cost trap** — pushing a finished app to polish instead of a clean kill/pivot/ship decision.
  5. The 434 words are a **sellable asset** independent of the app (book/deck/license).

---

## COUNCIL VERDICT

### Where the council agrees
- The hook works and would get **downloads**, but "wow words" is a **mood, not a habit** — no day-30 reason to return.
- The gamification (FSRS/quizzes/streaks) **contradicts the delight pitch** and serves neither audience.
- **434 words is a launch week, not a product**; the curated moat is also the churn cliff.
- **Monthly subscription is the wrong model**; lifetime/one-time at most; the 50-word paywall fires before any habit.
- You **can't answer "will they pay" from the armchair** — and with no analytics you're blind.

### Where the council clashes
- **Subtract vs. build:** strip to a pure free delight feed (First-Principles/Outsider) vs. build a content-IP/media brand with packs + gifting (Expansionist).
- **Is WTP real?** Identity spending → high (Expansionist) vs. free substitutes everywhere → structurally near-zero (everyone else + reviewers).

### Blind spots the council caught
The content-supply ceiling (moat = churn cliff, maybe unsolvable for a solo dev); the free-$0-substitute pricing problem; the solo-dev distribution bottleneck; the sunk-cost trap; the words as a standalone sellable asset.

### The recommendation
**Don't invest more months. Don't build the content empire. Run the cheapest test of the one thing that decides everything — and reframe before shipping.** As a paid subscription vocab app the council is bearish (no retention loop, free substitutes, unscalable catalogue). As a *shareable content brand with a beautiful app attached* there's a real but unproven shot. Method = Executor's; framing = First-Principles'; the Expansionist's empire is premature until two things are proven: the content travels as free social content, and anyone returns on day 7. Concretely: stop polishing; drop monthly (one-time/lifetime at most, don't tune it yet); make sure the share-card is social-ready; get it in front of strangers; read day-7 retention + share rate. If near zero → it's a gorgeous portfolio piece or a book, and shipping free is a fine outcome.

### The one thing to do first
**This week, before more code: post 8–10 word-cards as TikToks/Reels/IG carousels from a fresh Verbum account.** $0, no submission, tests the two things the business hinges on — does the content travel, and do people care when it's free? Flop → the funnel thesis is dead, months saved. Pop → you have a distribution engine and an audience to ship the TestFlight build to.

---

## Переклад вердикту (українською)

### У чому рада згодна
- Гачок працює, **завантаження будуть**, але «wow-слова» — це **настрій, а не звичка**: немає причини повертатись на 30-й день.
- Гейміфікація (FSRS/квізи/стріки) **суперечить позиціонуванню «насолода, не зубріння»** і не служить жодній аудиторії.
- **434 слова — це «тиждень запуску», а не продукт**; курований «рів» одночасно є й обривом відтоку.
- **Місячна підписка — неправильна модель**; максимум lifetime/разова; пейвол на 50-му слові спрацьовує до того, як сформувалась звичка.
- **Утримання не можна оцінити «з крісла»** — а без аналітики ти взагалі сліпий.

### Де рада не згодна
- **Прибрати vs. будувати:** звести до чистої безкоштовної «стрічки насолоди» (First-Principles/Outsider) vs. будувати контент-IP / медіа-бренд із паками + подарунками (Expansionist).
- **Чи реальна готовність платити?** Це витрати на «ідентичність» → висока (Expansionist) vs. безкоштовні замінники всюди → структурно близька до нуля (всі інші + рев'ю).

### Сліпі плями, які впіймала рада
Стеля постачання контенту (рів = обрив відтоку, можливо нерозв'язно для соло-розробника); проблема ціни проти безкоштовних замінників ($0); пляшкова шийка дистрибуції соло-розробника; пастка вкладених витрат; слова як самостійний продукт для продажу (книга/колода карток/ліцензія).

### Рекомендація
**Не вкладай ще місяці. Не будуй контент-імперію. Проведи найдешевший тест однієї речі, що вирішує все — і переформулюй до запуску.** Як платний підписковий словник — рада песимістична (немає циклу утримання, безкоштовні замінники, немасштабований каталог). Як *контент-бренд із гарним застосунком на додачу* — є реальний, але недоведений шанс. Метод — від Executor; рамка — від First-Principles; «імперія» Expansionist передчасна, поки не доведено два факти: контент поширюється як безкоштовний соц-контент, і хтось повертається на 7-й день. Конкретно: припини шліфувати; прибери місячну підписку (максимум разова/lifetime, поки не налаштовуй); зроби share-картку придатною для соцмереж; покажи її незнайомцям; виміряй утримання на 7-й день + частку поширень. Близько нуля → це чудовий портфоліо-проєкт або книга, і випустити безкоштовно — нормальний результат.

### Перший крок
**Цього тижня, до будь-якого коду: опублікуй 8–10 карток-слів як TikTok/Reels/IG-каруселі з нового акаунта Verbum.** $0, без сабміту в App Store, перевіряє дві речі, на яких тримається бізнес — чи поширюється контент і чи людям не байдуже, коли це безкоштовно. Провал → теза про «лійку» мертва, місяці зекономлено. Успіх → у тебе є двигун дистрибуції й аудиторія, якій можна дати TestFlight-білд.
