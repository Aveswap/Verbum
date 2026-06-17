import WidgetKit
import Foundation

struct WordEntry: TimelineEntry {
    let date: Date
    let word: SharedWordStore.DailyWord?
    let snapshot: SharedWordStore.Snapshot?
}

struct WordOfDayProvider: TimelineProvider {
    func placeholder(in context: Context) -> WordEntry {
        WordEntry(
            date: Date(),
            word: .init(
                date: Date(),
                id: UUID(),
                text: "serendipity",
                phonetic: "/ˌserənˈdɪpəti/",
                partOfSpeech: "noun",
                definition: "The chance occurrence of pleasant discoveries."
            ),
            snapshot: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WordEntry) -> Void) {
        completion(currentEntry(now: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WordEntry>) -> Void) {
        let now = Date()
        let snapshot = SharedWordStore.readSnapshot()
        let timeline = SharedWordStore.readTimeline().sorted { $0.date < $1.date }

        let entries: [WordEntry] = timeline.isEmpty
            ? [currentEntry(now: now)]
            : timeline.map { WordEntry(date: $0.date, word: $0, snapshot: snapshot) }

        let refresh = entries.last.map {
            Calendar.current.date(byAdding: .hour, value: 25, to: $0.date) ?? now.addingTimeInterval(3600)
        } ?? now.addingTimeInterval(3600)

        completion(Timeline(entries: entries, policy: .after(refresh)))
    }

    private func currentEntry(now: Date) -> WordEntry {
        let timeline = SharedWordStore.readTimeline()
        let today = Calendar.current.startOfDay(for: now)
        let pick = timeline.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
                ?? timeline.first
        return WordEntry(date: now, word: pick, snapshot: SharedWordStore.readSnapshot())
    }
}
