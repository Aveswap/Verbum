# Verbum — App Audit & Architecture Context

> Передай цей файл в новий чат з Claude щоб отримати повний контекст без зайвих питань.

---

## Що таке Verbum

iOS-додаток для вивчення англійських слів. Аналог "Vocabulary.com" / "Elevate".
Платформа: iOS 16+, SwiftUI, Swift 5.9, MVVM архітектура.
GitHub: https://github.com/Aveswap/Verbum.git
Проект зібраний через **xcodegen** (`project.yml`) — всі Swift-файли підхоплюються автоматично.

**Цільова аудиторія:** люди що хочуть розширити словниковий запас англійської — від початківців до просунутих.

**Монетизація:** Free (базові слова) + Premium (50k слів, всі функції).

---

## Технічний стек

| Компонент | Рішення |
|---|---|
| UI | SwiftUI |
| Архітектура | MVVM + `@EnvironmentObject` |
| Персистентність | UserDefaults (профіль) + SQLite/GRDB (слова) |
| База слів (зараз) | JSON бандл (150 слів) |
| База слів (premium) | SQLite `words.db` — завантажується з CDN один раз |
| Пошук | FTS5 virtual table в SQLite |
| Haptics | Core Haptics (CHHapticEngine) + UIKit fallback |
| Звук | AVAudioEngine, 4-node player pool |
| TTS | AVSpeechSynthesizer (en-US, rate 0.42) |
| Notifications | UNUserNotificationCenter |
| Widgets | WidgetKit (small, medium, lock screen) |
| Dependency | GRDB 6.29 via Swift Package Manager |

---

## Структура файлів

```
Verbum/
├── App/
│   ├── VerbumApp.swift          — @main, EnvironmentObject injection
│   └── AppCoordinator.swift     — onboarding gate
├── Core/
│   ├── Models/
│   │   ├── Word.swift           — головна модель слова
│   │   ├── UserProfile.swift    — профіль + streak + points + badges
│   │   ├── Badge.swift          — BadgeTier (gold/silver/bronze), EarnedBadge
│   │   └── Category.swift
│   ├── Data/
│   │   ├── WordRepository.swift — singleton, hybrid JSON/SQLite source
│   │   ├── WordDatabase.swift   — GRDB wrapper, schema, FTS5 queries
│   │   ├── DatabaseDownloadManager.swift — фоновий download CDN → local
│   │   ├── TranslationStore.swift — hybrid: SQLite → JSON bundle fallback
│   │   ├── WordStore.swift      — UserProfileStore (ObservableObject)
│   │   └── WordData.swift       — legacy shim → WordRepository
│   ├── Components/
│   │   ├── HapticManager.swift  — Core Haptics patterns
│   │   ├── SoundManager.swift   — синтезований звук (C-E-G chime)
│   │   └── DatabaseStatusBanner.swift — progress UI для download
│   └── Theme/
│       ├── Colors.swift         — AppColors
│       ├── Typography.swift     — AppTypography
│       └── Spacing.swift        — AppSpacing
├── Features/
│   ├── WordFeed/                — головний екран, swipe-карточки
│   ├── WordDetail/              — детальний вигляд слова
│   ├── WordList/                — Favorites, Liked, History
│   ├── Categories/              — CategoriesView, CategoryWordListView
│   ├── Practice/                — Quiz, FillGap, Synonyms, GuessWord, LevelTest
│   ├── Quiz/                    — BatchQuizView (кожні 5 слів)
│   ├── Leaderboard/             — рейтинг, badges, 1000 симульованих юзерів
│   ├── Stats/                   — статистика (streak, seen, bookmarks)
│   ├── Profile/                 — SettingsView, PremiumSheet, Notifications
│   └── Onboarding/              — OnboardingFlow, ProfileSetup, Welcome
└── Resources/
    ├── words.json               — 150 seed-слів у бандлі
    └── translations.json        — Ukrainian переклади для 150 слів
```

---

## Модель слова (Word.swift)

```swift
struct Word: Identifiable, Codable {
    let id: UUID
    let text: String
    let phonetic: String          // IPA, завжди є
    let partOfSpeech: String      // noun/verb/adjective/adverb/phrase/idiom
    let definition: String        // англійське визначення, max ~20 слів
    let exampleSentence: String?  // nullable
    let synonyms: [String]
    let category: String          // Food/Travel/Technology/Business/...
    let level: WordLevel          // rawValue: "beginner"/"intermediate"/"expert"
    var isBookmarked: Bool        // управляється UserProfileStore
    var isLiked: Bool             // управляється UserProfileStore
    let isNew: Bool
    let etymology: String?        // лише для expert, інакше null
}

enum WordLevel: String, Codable, CaseIterable {
    case beginner     // A1–A2
    case intermediate // B1–B2
    case expert       // C1–C2
}
```

**Важливо:** `isBookmarked` і `isLiked` — НЕ зберігаються в базі слів.
Вони живуть в `UserProfile.bookmarkedWordIds` / `likedWordIds` (масив UUID).
При відображенні — зіставляються в runtime.

---

## Рівні — поточне спрощення

Додаток зараз використовує 3 рівні замість 6 CEFR:

| App level | CEFR | Слів у базі (зараз) |
|---|---|---|
| beginner | A1–A2 | ~50 |
| intermediate | B1–B2 | ~60 |
| expert | C1–C2 | ~40 |

**Нюанс:** розподіл зараз довільний, не базується на реальних CEFR нормах.
Скільки слів реально потрібно на кожному рівні — відкрите питання (є в промті нижче).

---

## Переклади (TranslationStore.swift)

**Формат JSON-бандлу:**
```json
{
  "uk": {
    "<word-uuid-lowercase>": { "d": "переклад визначення", "e": "переклад прикладу" }
  }
}
```

**SQLite-схема (при premium DB):**
```sql
CREATE TABLE translations (
    word_id    TEXT NOT NULL REFERENCES words(id),
    lang       TEXT NOT NULL,   -- "uk", "de", "fr", "es", "pl", "it", "pt"
    definition TEXT NOT NULL,
    example    TEXT,
    PRIMARY KEY (word_id, lang)
);
```

**Пріоритет:** SQLite → JSON bundle fallback.
Після завантаження повної DB — bundle вивантажується з пам'яті.

**Підтримувані мови:**
`uk` Українська, `es` Español, `de` Deutsch, `fr` Français,
`pl` Polski, `it` Italiano, `pt` Português

---

## Профіль користувача

```swift
struct UserProfile: Codable {
    var name: String
    var age: AgeRange?           // 13-17 / 18-24 / 25-34 / 35-44 / 45-54 / 55+
    var gender: Gender?
    var level: WordLevel         // вибраний рівень
    var wordsPerWeek: Int        // ціль (1-100), default 30
    var nativeLanguage: String   // код мови для перекладів, default "en"
    var onboardingCompleted: Bool
    var bookmarkedWordIds: [UUID]
    var likedWordIds: [UUID]
    var seenWordIds: [UUID]
    var currentStreak: Int       // днів підряд
    var longestStreak: Int
    var lastOpenedDate: Date?
    var totalPoints: Int
    var quarterlyPoints: Int     // скидається кожні 3 місяці
    var quarterlyResetDate: Date
    var earnedBadges: [EarnedBadge]
}
```

Зберігається в `UserDefaults` як JSON. Дебаунс 0.5с на запис.
Критичні стани (streak, points, onboarding) — `saveNow()` без дебаунсу.

---

## Основний флоу (WordFeed)

1. Слова перемішуються при запуску (`shuffled()`)
2. Юзер свайпає картки вгору/вниз
3. Кожні **5 слів** → з'являється `BatchQuizView` (5 питань multiple choice)
4. Правильна відповідь → `HapticManager.correctAnswer()` + C→E→G chime
5. За правильну відповідь → `+10 points`
6. Streak рахується через `recordDailyOpen()` при кожному відкритті

**Batch quiz:** показує 5 слів з поточного батчу, 4 варіанти відповіді (1 правильний + 3 random).

---

## Практика (PracticeMenuView)

| Режим | Опис | Статус |
|---|---|---|
| Word Meaning | Вибери правильне визначення | ✅ Готово |
| Fill the Gap | Заповни пропуск у реченні | ✅ Готово |
| Find Synonyms | Знайди синоніми | ✅ Готово |
| Guess the Word | З визначення — назви слово | ✅ Готово |
| Level Test | Визначення рівня | ✅ Готово |
| Perfection/Rush/Sprint | Challenges | 🔒 Заблоковано (Premium) |

---

## Leaderboard

- 1000 детерміновано згенерованих симульованих юзерів
- Реальний юзер вставляється в рейтинг по `quarterlyPoints`
- Badges: Gold (top 10%) / Silver (top 25%) / Bronze (top 50%)
- Скидається кожні 3 місяці (квартально)

---

## База даних — архітектура (Variant C, гібрид)

```
App Store build → 150 слів у words.json (миттєвий старт)
                          ↓ перший запуск
              DatabaseDownloadManager (фоновий URLSession)
                          ↓
              CDN: words.db (~20-30 MB)  ← завантажується ОДИН раз
                          ↓ встановлено
              Application Support/Verbum/words.db
                          ↓
              WordDatabase (GRDB) — всі запити локально, без інтернету
```

**SQLite схема:**
```sql
words table:        id, text, phonetic, partOfSpeech, definition,
                    exampleSentence, synonyms(JSON), category, level, etymology
translations table: word_id, lang, definition, example  ← PRIMARY KEY (word_id, lang)
words_fts:          FTS5 virtual table (text, definition, category)
```

**Пошук:** `SELECT w.* FROM words w JOIN words_fts ON ... WHERE words_fts MATCH 'query*'`

**CDN URL** (placeholder, замінити коли база готова):
`https://cdn.verbum.app/words_v1.db`

---

## Відомі нюанси та обмеження

1. **`isBookmarked`/`isLiked` в Word struct** — архітектурний компроміс. При 50k слів ці поля завжди `false` в DB, реальний стан береться з `UserProfile`. Потенційно варто прибрати їх зі struct.

2. **`WordFeedViewModel` тягне `WordStore`** (а не `WordRepository`) — дублювання. При переході на DB потрібен рефактор feed'у на paginated запити.

3. **`StatsView` хардкодить `totalWords = 110`** — потрібно взяти з `WordRepository.totalWordCount`.

4. **Leaderboard симульований** — не реальні юзери. Для v2 потрібен backend.

5. **Теми (AppTheme)** — визначені в моделі (dark/light/forest/ocean/sunset/midnight), але тільки dark реалізована в кольорах.

6. **Batch quiz** рахує прогрес через `currentIndex % 5` — при фільтрації по категорії може показати quiz раніше ніж потрібно.

7. **WordRepository.all** — при DB повертає перші 200 слів (для feed). Для категорій/пошуку — прямий SQLite запит.

---

## Генерація бази слів

Скрипти в `scripts/`:
- `PROMPT_FOR_CLAUDE_PRO.md` — промт для ручної генерації (10 батчів × 500 = 5000 слів)
- `import_batch.py` — вставляєш відповідь Claude в `response.txt`, скрипт імпортує в SQLite
- `generate_words.py` — автоматичний варіант через Anthropic API (потрібен API key)

**Після генерації:** завантажити `words.db` на Supabase Storage або Cloudflare R2,
вставити URL в `DatabaseDownloadManager.remoteURL`.

---

## Відкриті питання для наступного чату

Дивись промт нижче.

---

# ПРОМТ ДЛЯ НОВОГО ЧАТУ (Learning Structure)

```
Я будую iOS-додаток Verbum для вивчення англійських слів.
Прочитай файл VERBUM_AUDIT.md — там повний контекст архітектури.

Тепер допоможи мені відповісти на стратегічні питання про структуру навчання:

## 1. Скільки слів потрібно на кожному рівні?

За даними лінгвістичних досліджень (Nation, Coxhead та ін.):
- Скільки слів активного словника потрібно для рівнів A1, A2, B1, B2, C1, C2?
- Яка різниця між активним (можу використати) і пасивним (розумію) словником?
- Скільки нових слів в день оптимально вчити на кожному рівні?

## 2. Як правильно структурувати базу 50,000 слів?

Ми плануємо:
- beginner (A1–A2): ~13,000 слів
- intermediate (B1–B2): ~24,000 слів
- expert (C1–C2): ~13,000 слів

Це правильний розподіл? Чи потрібно більше/менше на якомусь рівні?
Чи варто розбити 3 рівні на 6 (окремо A1, A2, B1, B2, C1, C2)?

## 3. Що повинна містити картка слова на кожному рівні?

Зараз кожне слово має:
- text (англійське слово)
- phonetic (IPA транскрипція)
- partOfSpeech
- definition (англійською)
- exampleSentence (nullable)
- synonyms (масив)
- category (тематика)
- etymology (лише для expert)
- переклад definition + exampleSentence на мову юзера

Питання:
- Чи достатньо одного exampleSentence? Скільки прикладів оптимально?
- Чи потрібен антонім (antonym) окремо від synonyms?
- Чи потрібна складність речення-прикладу відповідати рівню слова?
- Що важливіше для A1: переклад чи монолінгвальне визначення?
- Чи потрібна транскрипція (IPA) для всіх рівнів або тільки для початківців?

## 4. Алгоритм навчання

Зараз слова показуються в random порядку (shuffled).
Які є доведені алгоритми для запам'ятовування слів?
- Spaced repetition (SM-2, FSRS) — як це можна вбудувати в swipe-feed?
- Чи варто починати з найчастотніших слів (frequency lists)?
- Як визначити що слово "вивчене" в контексті мобільного додатку?

## 5. Категорії слів

Зараз маємо 16 категорій:
Food, Travel, Technology, Business, Nature, Health, Art,
Science, Social, Daily Life, Academic, Finance, Law, Sports, Emotion, Communication

Чи варто додати/прибрати якісь категорії для повноцінного покриття рівнів?
Які категорії найбільш важливі для A1–A2 vs C1–C2?

## 6. Переклади

Юзер вибирає рідну мову (uk/de/fr/es/pl/it/pt) і бачить переклад визначення і прикладу.
- Коли переклад шкодить навчанню (занадто рано)?
- На якому рівні варто "відключати" переклад за замовчуванням?
- Чи потрібен переклад самого слова (окремо від definition)?

Дай детальну відповідь з посиланнями на дослідження де можливо.
На основі відповідей — запропонуй конкретні зміни в архітектурі Word модель
і алгоритм показу слів для Verbum.
```
