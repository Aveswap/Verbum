import SwiftUI

/// Static, image-export-friendly rendering of a word. Rendered at 1080×1080 so the
/// resulting PNG/JPEG looks crisp on Instagram / Threads / iMessage / Twitter.
///
/// The view is intentionally simpler than `WordCardView`: no animations, no haptics,
/// no environment-object lookups — everything it needs comes through the initializer
/// so `ImageRenderer` can capture it off-screen reliably.
struct ShareableWordCard: View {
    let word: Word
    /// Optional native-language translation. Shown under the English definition.
    let translation: String?

    private let cardSize = CGSize(width: 1080, height: 1080)

    var body: some View {
        ZStack {
            // Background gradient — warm at top, deep navy at bottom
            LinearGradient(
                colors: [
                    Color(hex: "#0F1F25"),
                    Color(hex: "#1A2F38"),
                    Color(hex: "#0B1418")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle accent glow behind the word
            Circle()
                .fill(AppColors.accent.opacity(0.18))
                .frame(width: 700, height: 700)
                .blur(radius: 120)
                .offset(x: -100, y: -150)

            VStack(spacing: 36) {
                Spacer()

                // Verbum mark
                HStack(spacing: 10) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppColors.accent)
                    Text("VERBUM")
                        .font(.system(size: 20, weight: .black, design: .serif))
                        .tracking(8)
                        .foregroundColor(AppColors.accent)
                }

                // Word
                Text(word.text)
                    .font(.system(size: 140, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .padding(.horizontal, 60)

                // Phonetic
                Text(word.phonetic)
                    .font(.system(size: 32, weight: .light, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))

                // Part of speech pill
                Text(word.partOfSpeech.lowercased())
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(AppColors.textOnAccent)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 8)
                    .background(AppColors.accent)
                    .clipShape(Capsule())

                // Definition
                Text(word.definition)
                    .font(.system(size: 38, weight: .regular))
                    .foregroundColor(.white.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 80)
                    .lineLimit(4)
                    .minimumScaleFactor(0.5)

                if let translation, !translation.isEmpty {
                    Text(translation)
                        .font(.system(size: 28, weight: .regular).italic())
                        .foregroundColor(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 80)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                }

                Spacer()

                // Footer
                VStack(spacing: 6) {
                    Text("Learn one word a day")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                    Text("verbum.app")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppColors.accent)
                }
                .padding(.bottom, 60)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(width: cardSize.width, height: cardSize.height)
    }
}
