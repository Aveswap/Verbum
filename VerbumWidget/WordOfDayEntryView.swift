import SwiftUI
import WidgetKit

struct WordOfDayEntryView: View {
    let entry: WordEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall:  smallView
            case .systemMedium: mediumView
            case .systemLarge:  largeView
            default:            smallView
            }
        }
        .foregroundStyle(.white)
        // Tapping the widget opens the app straight to this word's detail (handled in VerbumApp).
        .widgetURL(entry.word.flatMap { URL(string: "verbum://word/\($0.id.uuidString)") })
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("WORD OF THE DAY")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(WidgetColors.accent)
            Spacer()
            if let word = entry.word {
                Text(word.text)
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(word.partOfSpeech)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(WidgetColors.accent)
            } else {
                Text("Open Verbum")
                    .font(.system(size: 14, weight: .semibold))
            }
            Spacer()
            if let s = entry.snapshot {
                streakPill(s)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var mediumView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("WORD OF THE DAY")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(WidgetColors.accent)
                if let word = entry.word {
                    Text(word.text)
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(word.phonetic)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.65))
                    Text(word.partOfSpeech)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(WidgetColors.accent)
                }
                Spacer()
                if let s = entry.snapshot {
                    streakPill(s)
                }
            }
            if let word = entry.word {
                VStack(alignment: .leading, spacing: 2) {
                    Text(word.definition)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(4)
                        .minimumScaleFactor(0.7)
                    if let t = word.translation {
                        Text(t)
                            .font(.system(size: 11).italic())
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("WORD OF THE DAY")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(WidgetColors.accent)
                Spacer()
                if let s = entry.snapshot {
                    streakPill(s)
                }
            }
            if let word = entry.word {
                VStack(alignment: .leading, spacing: 6) {
                    Text(word.text)
                        .font(.system(size: 44, weight: .bold, design: .serif))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    HStack(spacing: 10) {
                        Text(word.phonetic)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.65))
                        Text(word.partOfSpeech)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(WidgetColors.textOnAccent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(WidgetColors.accent))
                    }
                }
                Text(word.definition)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(4)
                if let t = word.translation {
                    Text(t)
                        .font(.system(size: 13).italic())
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(2)
                }
                Spacer()
                if let s = entry.snapshot, let free = s.freeRemaining, !s.isPro {
                    Text("\(free) free words left · Open to learn →")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.orange)
                } else if let s = entry.snapshot {
                    Text("\(s.wordsLearnedToday) of \(s.dailyGoal) learned today")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                }
            } else {
                Text("Open Verbum to set up your daily word.")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func streakPill(_ s: SharedWordStore.Snapshot) -> some View {
        HStack(spacing: 3) {
            Text("🔥")
                .font(.system(size: 10))
            Text("\(s.currentStreak)")
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(.white.opacity(0.12)))
    }
}

enum WidgetColors {
    static let accent       = Color(hex: "#6ECFCF")
    static let textOnAccent = Color.black
}

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        self.init(.sRGB,
                  red:   Double((v >> 16) & 0xff) / 255,
                  green: Double((v >> 8)  & 0xff) / 255,
                  blue:  Double(v & 0xff) / 255,
                  opacity: 1)
    }
}
