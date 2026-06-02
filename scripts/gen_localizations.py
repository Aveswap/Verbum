#!/usr/bin/env python3
"""
Generate Verbum/Resources/{de,uk,en}.lproj/Localizable.strings from a translation map keyed by
the exact English source string (the same literal the SwiftUI `Text(...)` uses, so no view
changes are needed). Keys absent from the map are emitted in `en` only and simply fall back to
English in de/uk at runtime — never a crash.

Run:  python3 gen_localizations.py
"""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
KEYS = json.load(open(os.path.join(HERE, "_ui_strings.json"), encoding="utf-8"))
RES = os.path.join(HERE, "..", "Verbum", "Resources")

# key -> (German, Ukrainian). Brand/symbol-only strings are intentionally omitted (kept English).
T = {
 "/ 7 days opened": ("/ 7 Tage geöffnet", "/ 7 днів відкрито"),
 "About You": ("Über dich", "Про тебе"),
 "Account": ("Konto", "Обліковий запис"),
 "Add friends on Game Center to compare progress": ("Füge Freunde im Game Center hinzu, um Fortschritte zu vergleichen", "Додай друзів у Game Center, щоб порівнювати прогрес"),
 "Add to deck": ("Zum Stapel hinzufügen", "Додати до колоди"),
 "All caught up!": ("Alles erledigt!", "Усе пройдено!"),
 "All words and features unlocked": ("Alle Wörter und Funktionen freigeschaltet", "Усі слова та функції відкрито"),
 "Bookmarked": ("Gemerkt", "Збережені"),
 "Cancel": ("Abbrechen", "Скасувати"),
 "Casual": ("Locker", "Спокійний"),
 "Check your connection and try again.": ("Prüfe deine Verbindung und versuche es erneut.", "Перевір з’єднання та спробуй ще раз."),
 "Choose the correct definition": ("Wähle die richtige Definition", "Обери правильне визначення"),
 "Close": ("Schließen", "Закрити"),
 "Community": ("Gemeinschaft", "Спільнота"),
 "Continue": ("Weiter", "Продовжити"),
 "Create": ("Erstellen", "Створити"),
 "Current Streak": ("Aktuelle Serie", "Поточна серія"),
 "Daily Goal": ("Tagesziel", "Денна ціль"),
 "Daily goal reached!": ("Tagesziel erreicht!", "Денну ціль досягнуто!"),
 "Daily limit reached · Resets at midnight": ("Tageslimit erreicht · Setzt um Mitternacht zurück", "Денний ліміт вичерпано · Скидається опівночі"),
 "Deck name": ("Stapelname", "Назва колоди"),
 "Delete Account": ("Konto löschen", "Видалити обліковий запис"),
 "Delete All Data": ("Alle Daten löschen", "Видалити всі дані"),
 "Developer": ("Entwickler", "Розробник"),
 "Dictionary": ("Wörterbuch", "Словник"),
 "Done": ("Fertig", "Готово"),
 "Download": ("Herunterladen", "Завантажити"),
 "Download failed": ("Download fehlgeschlagen", "Не вдалося завантажити"),
 "Download the full 1,000-word dictionary": ("Lade das vollständige Wörterbuch mit 1.000 Wörtern herunter", "Завантаж повний словник на 1 000 слів"),
 "Downloading dictionary…": ("Wörterbuch wird heruntergeladen…", "Завантаження словника…"),
 "EARNED BADGES": ("VERDIENTE ABZEICHEN", "ЗДОБУТІ ВІДЗНАКИ"),
 "Enable Notifications": ("Mitteilungen aktivieren", "Увімкнути сповіщення"),
 "Enter name": ("Namen eingeben", "Введи ім’я"),
 "Example": ("Beispiel", "Приклад"),
 "Explore": ("Entdecken", "Огляд"),
 "Fill in the blank": ("Lücke ausfüllen", "Заповни пропуск"),
 "Fill the Gap": ("Lücke füllen", "Заповни пропуск"),
 "Find Synonyms": ("Synonyme finden", "Знайди синоніми"),
 "Find a synonym for": ("Finde ein Synonym für", "Знайди синонім до"),
 "Finished!": ("Fertig!", "Завершено!"),
 "Friends": ("Freunde", "Друзі"),
 "Full Dictionary": ("Vollständiges Wörterbuch", "Повний словник"),
 "Get Premium": ("Premium holen", "Отримати Premium"),
 "Go Premium": ("Premium werden", "Перейти на Premium"),
 "Go Premium to unlock the rest of the catalog": ("Werde Premium, um den restlichen Katalog freizuschalten", "Перейди на Premium, щоб відкрити решту каталогу"),
 "Go to Practice": ("Zum Üben", "До практики"),
 "Group words into custom collections to study what matters to you.": ("Fasse Wörter in eigenen Sammlungen zusammen, um gezielt zu lernen.", "Групуй слова у власні колекції, щоб вчити саме потрібне."),
 "Guess the Word": ("Wort erraten", "Вгадай слово"),
 "How many words do you want to learn per week?": ("Wie viele Wörter möchtest du pro Woche lernen?", "Скільки слів ти хочеш вивчати щотижня?"),
 "In 30 days, you'll know": ("In 30 Tagen kennst du", "За 30 днів ти знатимеш"),
 "Intense": ("Intensiv", "Інтенсивний"),
 "Invite Friends": ("Freunde einladen", "Запросити друзів"),
 "Learn first, then practice": ("Erst lernen, dann üben", "Спершу вчися, потім практикуйся"),
 "Learn new words every day in just 1 minute": ("Lerne jeden Tag in nur 1 Minute neue Wörter", "Вивчай нові слова щодня лише за 1 хвилину"),
 "Learn one word a day": ("Lerne ein Wort pro Tag", "Вивчай одне слово на день"),
 "Learn without limits": ("Lerne ohne Grenzen", "Навчайся без обмежень"),
 "Less than 2 minutes a day. You can change this anytime in Settings.": ("Weniger als 2 Minuten am Tag. Du kannst das jederzeit in den Einstellungen ändern.", "Менше ніж 2 хвилини на день. Це можна змінити будь-коли в налаштуваннях."),
 "Level Test": ("Niveautest", "Тест рівня"),
 "Liked": ("Gefällt mir", "Уподобані"),
 "MILESTONES": ("MEILENSTEINE", "ВІХИ"),
 "Mastery Distribution": ("Verteilung der Beherrschung", "Розподіл засвоєння"),
 "My Decks": ("Meine Stapel", "Мої колоди"),
 "My Progress": ("Mein Fortschritt", "Мій прогрес"),
 "NEW": ("NEU", "НОВЕ"),
 "New Deck": ("Neuer Stapel", "Нова колода"),
 "Nice work!": ("Gut gemacht!", "Гарна робота!"),
 "No decks yet": ("Noch keine Stapel", "Поки що немає колод"),
 "Not enough new words to quiz yet": ("Noch nicht genug neue Wörter für ein Quiz", "Поки замало нових слів для вікторини"),
 "Notifications": ("Mitteilungen", "Сповіщення"),
 "Notifications per day": ("Mitteilungen pro Tag", "Сповіщень на день"),
 "Number (1–100)": ("Zahl (1–100)", "Число (1–100)"),
 "Plans couldn’t be loaded": ("Tarife konnten nicht geladen werden", "Не вдалося завантажити тарифи"),
 "Practice": ("Üben", "Практика"),
 "Premium": ("Premium", "Premium"),
 "Premium word": ("Premium-Wort", "Premium-слово"),
 "Profile": ("Profil", "Профіль"),
 "Quiz Complete!": ("Quiz abgeschlossen!", "Вікторину завершено!"),
 "Quiz after next word! 🧠": ("Quiz nach dem nächsten Wort! 🧠", "Вікторина після наступного слова! 🧠"),
 "Renew anytime to unlock every word again.": ("Verlängere jederzeit, um wieder alle Wörter freizuschalten.", "Поновлюй будь-коли, щоб знову відкрити всі слова."),
 "Reset Onboarding": ("Einführung zurücksetzen", "Скинути онбординг"),
 "Restart Feed": ("Feed neu starten", "Перезапустити стрічку"),
 "Restore": ("Wiederherstellen", "Відновити"),
 "Restore Purchases": ("Käufe wiederherstellen", "Відновити покупки"),
 "Retry": ("Erneut versuchen", "Повторити"),
 "Save": ("Speichern", "Зберегти"),
 "Saved Words": ("Gespeicherte Wörter", "Збережені слова"),
 "Search": ("Suchen", "Пошук"),
 "Search learned words": ("Gelernte Wörter durchsuchen", "Шукати серед вивчених слів"),
 "Search words…": ("Wörter suchen…", "Шукати слова…"),
 "Select Age Range": ("Altersbereich wählen", "Обери віковий діапазон"),
 "Select Gender": ("Geschlecht wählen", "Обери стать"),
 "Select Level": ("Niveau wählen", "Обери рівень"),
 "Serious": ("Ernsthaft", "Серйозний"),
 "Set as My Level": ("Als mein Niveau festlegen", "Зробити моїм рівнем"),
 "Set up notifications": ("Mitteilungen einrichten", "Налаштувати сповіщення"),
 "Settings": ("Einstellungen", "Налаштування"),
 "Share": ("Teilen", "Поділитися"),
 "Share Verbum and learn together": ("Teile Verbum und lernt gemeinsam", "Поділися Verbum і вчіться разом"),
 "Share Word": ("Wort teilen", "Поділитися словом"),
 "Share word": ("Wort teilen", "Поділитися словом"),
 "Sharing brings new learners to Verbum — thanks for the assist 🎯": ("Teilen bringt neue Lernende zu Verbum — danke für die Hilfe 🎯", "Поширення приводить нових учнів до Verbum — дякуємо за допомогу 🎯"),
 "Sign Out": ("Abmelden", "Вийти"),
 "Signed in with Apple": ("Mit Apple angemeldet", "Вхід через Apple"),
 "Skip": ("Überspringen", "Пропустити"),
 "Sound": ("Ton", "Звук"),
 "Spaced repetition keeps memory fresh — open the feed to review.": ("Verteiltes Wiederholen hält das Gedächtnis frisch — öffne den Feed zum Wiederholen.", "Інтервальне повторення освіжає пам’ять — відкрий стрічку для повторення."),
 "Spread between 9 AM and 10 PM": ("Verteilt zwischen 9 und 22 Uhr", "Розподілено між 9:00 та 22:00"),
 "Statistics": ("Statistik", "Статистика"),
 "Swipe up for the next word": ("Wische nach oben für das nächste Wort", "Гортай угору для наступного слова"),
 "Take Level Test": ("Niveautest machen", "Пройти тест рівня"),
 "Take the test to find your level": ("Mach den Test, um dein Niveau zu finden", "Пройди тест, щоб визначити свій рівень"),
 "Tap all the words you recognise": ("Tippe alle Wörter an, die du kennst", "Торкнися всіх слів, які впізнаєш"),
 "This Week": ("Diese Woche", "Цей тиждень"),
 "This permanently deletes all your progress, streaks, and settings. This cannot be undone.": ("Dies löscht dauerhaft deinen gesamten Fortschritt, deine Serien und Einstellungen. Das kann nicht rückgängig gemacht werden.", "Це назавжди видалить весь твій прогрес, серії та налаштування. Скасувати неможливо."),
 "This quarter": ("Dieses Quartal", "Цей квартал"),
 "This word has a fascinating history": ("Dieses Wort hat eine faszinierende Geschichte", "Це слово має захопливу історію"),
 "Unlock": ("Freischalten", "Відкрити"),
 "Unlock 1,000+ words across all difficulty levels.": ("Schalte über 1.000 Wörter aller Schwierigkeitsstufen frei.", "Відкрий понад 1 000 слів усіх рівнів складності."),
 "Unlock All": ("Alles freischalten", "Відкрити все"),
 "Unlock all words & practice modes": ("Alle Wörter und Übungsmodi freischalten", "Відкрий усі слова та режими практики"),
 "Verbum Premium": ("Verbum Premium", "Verbum Premium"),
 "View Progress": ("Fortschritt ansehen", "Переглянути прогрес"),
 "We'll use this to personalise your learning": ("Wir nutzen das, um dein Lernen zu personalisieren", "Ми використаємо це, щоб персоналізувати твоє навчання"),
 "Well done!": ("Gut gemacht!", "Молодець!"),
 "What does this word mean?": ("Was bedeutet dieses Wort?", "Що означає це слово?"),
 "What's your level?": ("Was ist dein Niveau?", "Який твій рівень?"),
 "What's your name?": ("Wie heißt du?", "Як тебе звати?"),
 "Which word matches this definition?": ("Welches Wort passt zu dieser Definition?", "Яке слово відповідає цьому визначенню?"),
 "Word History": ("Wortgeschichte", "Історія слова"),
 "Word Language": ("Sprache der Wörter", "Мова слів"),
 "Word Meaning": ("Wortbedeutung", "Значення слова"),
 "Word details": ("Wortdetails", "Деталі слова"),
 "Words Discovered": ("Entdeckte Wörter", "Відкрито слів"),
 "Words per week": ("Wörter pro Woche", "Слів на тиждень"),
 "Your Name": ("Dein Name", "Твоє ім’я"),
 "Your Profile": ("Dein Profil", "Твій профіль"),
 "Your name": ("Dein Name", "Твоє ім’я"),
 "Your subscription has ended": ("Dein Abo ist abgelaufen", "Твоя підписка завершилася"),
 "Your word of the day is ready! 📖": ("Dein Wort des Tages ist bereit! 📖", "Твоє слово дня готове! 📖"),
 "days": ("Tage", "днів"),
 "new words": ("neue Wörter", "нових слів"),
 "now": ("jetzt", "зараз"),
 "points earned": ("Punkte verdient", "очок здобуто"),
 "pts": ("Pkt.", "оч."),
 "words per day": ("Wörter pro Tag", "слів на день"),
 "✨ +50 perfect bonus included": ("✨ +50 Perfekt-Bonus inklusive", "✨ +50 бонус за бездоганність"),
}

def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')

def write(lang, idx):
    out = ['/* Verbum UI — %s (generated by gen_localizations.py) */' % lang, ""]
    for k in KEYS:
        if lang == "en":
            out.append(f'"{esc(k)}" = "{esc(k)}";')
        elif k in T:
            out.append(f'"{esc(k)}" = "{esc(T[k][idx])}";')
    d = os.path.join(RES, f"{lang}.lproj")
    os.makedirs(d, exist_ok=True)
    open(os.path.join(d, "Localizable.strings"), "w", encoding="utf-8").write("\n".join(out) + "\n")
    return sum(1 for k in KEYS if lang == "en" or k in T)

for lang, idx in [("en", None), ("de", 0), ("uk", 1)]:
    n = write(lang, idx)
    print(f"{lang}: {n} strings")
print(f"translated keys: {len(T)} / {len(KEYS)} static literals")
