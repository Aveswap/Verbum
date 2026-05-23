import WidgetKit
import SwiftUI

// MARK: - Shared Word Model (duplicated for widget bundle isolation)

struct WidgetWord: Codable {
    let text: String
    let phonetic: String
    let partOfSpeech: String
    let definition: String
    let level: String
}

// MARK: - Timeline Entry

struct WordOfDayEntry: TimelineEntry {
    let date: Date
    let word: WidgetWord
}

// MARK: - Provider

struct WordProvider: TimelineProvider {
    func placeholder(in context: Context) -> WordOfDayEntry {
        WordOfDayEntry(date: Date(), word: WidgetWord(
            text: "ephemeral",
            phonetic: "/ɪˈfem.ər.əl/",
            partOfSpeech: "adj.",
            definition: "Lasting for a very short time",
            level: "intermediate"
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (WordOfDayEntry) -> Void) {
        completion(WordOfDayEntry(date: Date(), word: todaysWord()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WordOfDayEntry>) -> Void) {
        let entry = WordOfDayEntry(date: Date(), word: todaysWord())
        // Refresh at next 00:01
        let nextMidnight = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 1),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(86400)
        let timeline = Timeline(entries: [entry], policy: .after(nextMidnight))
        completion(timeline)
    }

    private func todaysWord() -> WidgetWord {
        guard let url = Bundle.main.url(forResource: "words", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let words = try? JSONDecoder().decode([WidgetWord].self, from: data),
              !words.isEmpty
        else {
            return WidgetWord(
                text: "ephemeral",
                phonetic: "/ɪˈfem.ər.əl/",
                partOfSpeech: "adj.",
                definition: "Lasting for a very short time",
                level: "intermediate"
            )
        }
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return words[(dayIndex - 1) % words.count]
    }
}

// MARK: - Widget Views

struct VerbumWidgetSmallView: View {
    let entry: WordOfDayEntry

    var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.118) // #1C1C1E
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("VERBUM")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(red: 0.494, green: 0.784, blue: 0.784))
                    Spacer()
                    Image(systemName: "book.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(red: 0.494, green: 0.784, blue: 0.784))
                }

                Spacer()

                Text(entry.word.text)
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                Text(entry.word.phonetic)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(red: 0.557, green: 0.557, blue: 0.576))

                Text(entry.word.definition)
                    .font(.system(size: 11))
                    .foregroundColor(Color(red: 0.557, green: 0.557, blue: 0.576))
                    .lineLimit(2)
            }
            .padding(14)
        }
    }
}

struct VerbumWidgetMediumView: View {
    let entry: WordOfDayEntry

    var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.118)
            HStack(spacing: 16) {
                // Left side
                VStack(alignment: .leading, spacing: 6) {
                    Text("WORD OF THE DAY")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(red: 0.494, green: 0.784, blue: 0.784))

                    Text(entry.word.text)
                        .font(.system(size: 26, weight: .bold, design: .serif))
                        .foregroundColor(.white)

                    Text(entry.word.phonetic)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(red: 0.557, green: 0.557, blue: 0.576))

                    HStack(spacing: 4) {
                        Text(entry.word.partOfSpeech)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(red: 0.494, green: 0.784, blue: 0.784))
                        Text(entry.word.level)
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(red: 0.494, green: 0.784, blue: 0.784).opacity(0.3))
                            .cornerRadius(8)
                    }

                    Spacer()
                }

                // Divider
                Rectangle()
                    .fill(Color(red: 0.173, green: 0.173, blue: 0.18))
                    .frame(width: 1)

                // Right side - definition
                VStack(alignment: .leading, spacing: 6) {
                    Text("Definition")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(red: 0.557, green: 0.557, blue: 0.576))

                    Text(entry.word.definition)
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .lineLimit(4)

                    Spacer()
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Lock Screen Views

struct VerbumWidgetRectangularView: View {
    let entry: WordOfDayEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.word.text)
                .font(.system(size: 15, weight: .bold, design: .serif))
                .foregroundColor(.white)
            Text(entry.word.phonetic)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
            Text(entry.word.definition)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct VerbumWidgetInlineView: View {
    let entry: WordOfDayEntry
    var body: some View {
        Text("\(entry.word.text) — \(entry.word.definition)")
            .lineLimit(1)
    }
}

// MARK: - Widget Configuration

struct VerbumWidget: Widget {
    let kind = "VerbumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WordProvider()) { entry in
            if #available(iOS 17.0, *) {
                VerbumWidgetSmallView(entry: entry)
                    .containerBackground(.black, for: .widget)
            } else {
                VerbumWidgetSmallView(entry: entry)
            }
        }
        .configurationDisplayName("Word of the Day")
        .description("Learn a new word every day from your home screen.")
        .supportedFamilies([.systemSmall])
    }
}

struct VerbumWidgetMedium: Widget {
    let kind = "VerbumWidgetMedium"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WordProvider()) { entry in
            if #available(iOS 17.0, *) {
                VerbumWidgetMediumView(entry: entry)
                    .containerBackground(.black, for: .widget)
            } else {
                VerbumWidgetMediumView(entry: entry)
            }
        }
        .configurationDisplayName("Word of the Day")
        .description("Learn a new word every day from your home screen.")
        .supportedFamilies([.systemMedium])
    }
}

struct VerbumLockScreenWidget: Widget {
    let kind = "VerbumLockScreen"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WordProvider()) { entry in
            VerbumWidgetRectangularView(entry: entry)
        }
        .configurationDisplayName("Word of the Day")
        .description("See today's word on your lock screen.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Bundle

@main
struct VerbumWidgetBundle: WidgetBundle {
    var body: some Widget {
        VerbumWidget()
        VerbumWidgetMedium()
        VerbumLockScreenWidget()
    }
}
