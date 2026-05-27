import SwiftUI

/// Apple Watch glance: today's word + tomorrow's preview + streak.
/// Pulls everything from the App Group store — no network, no DB.
struct WatchHomeView: View {
    @State private var timeline: [SharedWordStore.DailyWord] = []
    @State private var snapshot: SharedWordStore.Snapshot?
    @State private var showTomorrow = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                header
                if let today = todaysWord {
                    wordCard(today, isTomorrow: false)
                } else {
                    emptyHint
                }
                if showTomorrow, let tomorrow = tomorrowsWord {
                    Text("TOMORROW")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(WatchColors.accent)
                        .padding(.top, 4)
                    wordCard(tomorrow, isTomorrow: true)
                } else if tomorrowsWord != nil {
                    Button { withAnimation { showTomorrow = true } } label: {
                        Label("Show tomorrow", systemImage: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.borderless)
                    .tint(WatchColors.accent)
                }
            }
            .padding(.horizontal, 8)
        }
        .onAppear(perform: reload)
        // Refresh whenever the user re-raises their wrist
        .onReceive(NotificationCenter.default.publisher(for: .NSExtensionHostWillEnterForeground)) { _ in
            reload()
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Text("VERBUM")
                .font(.system(size: 10, weight: .black, design: .serif))
                .tracking(2)
                .foregroundStyle(WatchColors.accent)
            Spacer()
            if let s = snapshot {
                Text("🔥 \(s.currentStreak)")
                    .font(.system(size: 11, weight: .bold))
            }
        }
    }

    private func wordCard(_ w: SharedWordStore.DailyWord, isTomorrow: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(w.text)
                .font(.system(size: 22, weight: .bold, design: .serif))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .blur(radius: isTomorrow ? 3 : 0)
            Text(w.phonetic)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.gray)
                .lineLimit(1)
            Text(w.partOfSpeech)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(WatchColors.accent)
            if !isTomorrow {
                Text(w.definition)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(6)
                    .padding(.top, 2)
                if let t = w.translation {
                    Text(t)
                        .font(.system(size: 11).italic())
                        .foregroundStyle(.gray)
                        .lineLimit(3)
                }
            } else {
                Text("Tap to reveal at midnight")
                    .font(.system(size: 10))
                    .foregroundStyle(.gray)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.06)))
    }

    private var emptyHint: some View {
        VStack(spacing: 8) {
            Image(systemName: "iphone.gen3")
                .font(.system(size: 24))
                .foregroundStyle(WatchColors.accent)
            Text("Open Verbum on your iPhone to sync today's word.")
                .font(.system(size: 12))
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private var todaysWord: SharedWordStore.DailyWord? {
        let today = Calendar.current.startOfDay(for: Date())
        return timeline.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    private var tomorrowsWord: SharedWordStore.DailyWord? {
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now) else { return nil }
        let target = Calendar.current.startOfDay(for: tomorrow)
        return timeline.first { Calendar.current.isDate($0.date, inSameDayAs: target) }
    }

    private func reload() {
        timeline = SharedWordStore.readTimeline().sorted { $0.date < $1.date }
        snapshot = SharedWordStore.readSnapshot()
    }
}

enum WatchColors {
    static let accent = Color(hex: "#6ECFCF")
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
