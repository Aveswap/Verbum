import WidgetKit
import SwiftUI

// Home-screen Word-of-the-Day widgets (small / medium / large) live in WordOfDayWidget.swift
// and read the real, language- and level-aware timeline the app writes to the shared App Group
// (SharedWordStore). This file now only hosts the lock-screen widgets, fed by the same source —
// the previous words.json-backed implementation was a stale, English-only duplicate.

// MARK: - Lock-screen entry / provider

struct LockScreenEntry: TimelineEntry {
    let date: Date
    let word: SharedWordStore.DailyWord?
}

struct LockScreenProvider: TimelineProvider {
    private var placeholderWord: SharedWordStore.DailyWord {
        SharedWordStore.DailyWord(
            date: Date(), id: UUID(),
            text: "ephemeral", phonetic: "/ɪˈfem.ər.əl/", partOfSpeech: "adj.",
            definition: "Lasting for a very short time", translation: nil
        )
    }

    func placeholder(in context: Context) -> LockScreenEntry {
        LockScreenEntry(date: Date(), word: placeholderWord)
    }

    func getSnapshot(in context: Context, completion: @escaping (LockScreenEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LockScreenEntry>) -> Void) {
        // One entry per day from the shared timeline; refresh after the last one.
        let timeline = SharedWordStore.readTimeline().sorted { $0.date < $1.date }
        let entries: [LockScreenEntry] = timeline.isEmpty
            ? [currentEntry()]
            : timeline.map { LockScreenEntry(date: $0.date, word: $0) }
        let refresh = Calendar.current.nextDate(
            after: Date(), matching: DateComponents(hour: 0, minute: 1), matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(86400)
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }

    private func currentEntry() -> LockScreenEntry {
        let today = SharedWordStore.readTimeline()
            .filter { $0.date <= Date() }
            .max { $0.date < $1.date }
        return LockScreenEntry(date: Date(), word: today ?? placeholderWord)
    }
}

// MARK: - Lock-screen views

struct VerbumWidgetRectangularView: View {
    let entry: LockScreenEntry
    var body: some View {
        let word = entry.word
        VStack(alignment: .leading, spacing: 2) {
            Text(word?.text ?? "Verbum")
                .font(.system(size: 15, weight: .bold, design: .serif))
                .foregroundColor(.white)
            if let phonetic = word?.phonetic, !phonetic.isEmpty {
                Text(phonetic)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }
            Text(word?.definition ?? "Open Verbum for today's word")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct VerbumWidgetInlineView: View {
    let entry: LockScreenEntry
    var body: some View {
        if let word = entry.word {
            Text("\(word.text) — \(word.definition)").lineLimit(1)
        } else {
            Text("Verbum · Word of the Day").lineLimit(1)
        }
    }
}

// MARK: - Lock-screen widget configuration

struct VerbumLockScreenWidget: Widget {
    let kind = "VerbumLockScreen"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockScreenProvider()) { entry in
            LockScreenRouter(entry: entry)
        }
        .configurationDisplayName("Word of the Day")
        .description("See today's word on your lock screen.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}

/// Picks the right lock-screen layout for the requested family.
private struct LockScreenRouter: View {
    @Environment(\.widgetFamily) private var family
    let entry: LockScreenEntry
    var body: some View {
        content
            // Tapping the lock-screen widget opens the app straight to this word's detail
            // (verbum://word/<uuid> → onOpenURL in VerbumApp → WordDetailView).
            .widgetURL(entry.word.flatMap { URL(string: "verbum://word/\($0.id.uuidString)") })
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryInline: VerbumWidgetInlineView(entry: entry)
        default:               VerbumWidgetRectangularView(entry: entry)
        }
    }
}
