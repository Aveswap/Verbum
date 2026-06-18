import SwiftUI

/// Export format for a shareable word card.
/// - `.square` (1080×1080) for the Instagram/Threads feed and carousels.
/// - `.story`  (1080×1920) for Reels / TikTok / Stories — the vertical channels that are the
///   app's primary content-funnel distribution. The story variant also shows the example
///   sentence (it has the room, and the example is often the most shareable line).
enum ShareCardFormat: String, CaseIterable, Identifiable {
    case story
    case square

    var id: String { rawValue }
    var displayName: String { self == .square ? "Square" : "Story / Reel" }
    var size: CGSize { self == .square ? CGSize(width: 1080, height: 1080) : CGSize(width: 1080, height: 1920) }
    /// width / height — drives the on-screen preview's aspect ratio.
    var aspectRatio: CGFloat { size.width / size.height }

    struct Metrics {
        var stackSpacing: CGFloat
        var wordmark: CGFloat
        var word: CGFloat
        var phonetic: CGFloat
        var pos: CGFloat
        var definition: CGFloat
        var definitionLines: Int
        var example: CGFloat
        var footerTagline: CGFloat
        var footerHandle: CGFloat
        var bottomPadding: CGFloat
        var showsExample: Bool
    }

    var metrics: Metrics {
        switch self {
        case .square:
            return Metrics(stackSpacing: 30, wordmark: 20, word: 140, phonetic: 32, pos: 22,
                           definition: 38, definitionLines: 4, example: 0,
                           footerTagline: 22, footerHandle: 18, bottomPadding: 60, showsExample: false)
        case .story:
            return Metrics(stackSpacing: 42, wordmark: 26, word: 150, phonetic: 36, pos: 26,
                           definition: 44, definitionLines: 5, example: 36,
                           footerTagline: 28, footerHandle: 24, bottomPadding: 120, showsExample: true)
        }
    }
}

/// Static, image-export-friendly rendering of a word. Rendered at the format's pixel size so the
/// resulting PNG looks crisp on Instagram / Threads / Reels / TikTok / Stories.
struct ShareableWordCard: View {
    let word: Word
    var format: ShareCardFormat = .square

    var body: some View {
        let m = format.metrics
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "#0F1F25"),
                    Color(hex: "#1A2F38"),
                    Color(hex: "#0B1418")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(AppColors.accent.opacity(0.18))
                .frame(width: 700, height: 700)
                .blur(radius: 120)
                .offset(x: -100, y: format == .story ? -400 : -150)

            VStack(spacing: m.stackSpacing) {
                Spacer()

                HStack(spacing: 10) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: m.wordmark + 2, weight: .bold))
                        .foregroundColor(AppColors.accent)
                    Text("VERBUM")
                        .font(.system(size: m.wordmark, weight: .black, design: .serif))
                        .tracking(8)
                        .foregroundColor(AppColors.accent)
                }

                Text(word.text)
                    .font(.system(size: m.word, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .padding(.horizontal, 60)

                if !word.phonetic.isEmpty {
                    Text(word.phonetic)
                        .font(.system(size: m.phonetic, weight: .light, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }

                Text(word.localizedPartOfSpeech.lowercased())
                    .font(.system(size: m.pos, weight: .semibold))
                    .foregroundColor(AppColors.textOnAccent)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 8)
                    .background(AppColors.accent)
                    .clipShape(Capsule())

                Text(word.definition)
                    .font(.system(size: m.definition, weight: .regular))
                    .foregroundColor(.white.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 80)
                    .lineLimit(m.definitionLines)
                    .minimumScaleFactor(0.5)

                if m.showsExample, let example = word.exampleSentence, !example.isEmpty {
                    Text("\u{201C}\(example)\u{201D}")
                        .font(.system(size: m.example, weight: .regular).italic())
                        .foregroundColor(.white.opacity(0.62))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 90)
                        .lineLimit(4)
                        .minimumScaleFactor(0.5)
                }

                Spacer()

                VStack(spacing: 8) {
                    Text("A beautiful word every day")
                        .font(.system(size: m.footerTagline, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                    Text(AppInfo.socialHandle)
                        .font(.system(size: m.footerHandle, weight: .medium))
                        .foregroundColor(AppColors.accent)
                }
                .padding(.bottom, m.bottomPadding)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(width: format.size.width, height: format.size.height)
    }
}
