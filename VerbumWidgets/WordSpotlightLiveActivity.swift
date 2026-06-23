import ActivityKit
import WidgetKit
import SwiftUI

/// The "word spotlight" Live Activity: a claimed/daily word pinned to the Lock Screen and the
/// Dynamic Island. Self-contained styling (no app design-token dependency) so the widget extension
/// stays lean — it only needs ActivityKit + WidgetKit + the shared WordActivityAttributes.
@available(iOS 16.2, *)
struct WordSpotlightLiveActivity: Widget {
    private let accent = Color(red: 0.45, green: 0.78, blue: 0.85)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WordActivityAttributes.self) { context in
            // Lock Screen / notification-banner presentation.
            HStack(spacing: 12) {
                Image(systemName: "book.closed.fill")
                    .font(.title3)
                    .foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(context.attributes.word)
                        .font(.system(size: 19, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                    if context.state.revealed {
                        Text("\(context.attributes.partOfSpeech) \(context.attributes.definition)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(2)
                            .transition(.opacity)
                    }
                }
                Spacer()
            }
            .padding(14)
            .activityBackgroundTint(Color.black.opacity(0.45))
            .activitySystemActionForegroundColor(accent)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded (long-press) presentation.
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "book.closed.fill").foregroundStyle(accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if !context.attributes.phonetic.isEmpty {
                        Text(context.attributes.phonetic)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.word)
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.revealed {
                        Text("\(context.attributes.partOfSpeech) \(context.attributes.definition)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .transition(.opacity)
                    }
                }
            } compactLeading: {
                Image(systemName: "book.closed.fill").foregroundStyle(accent)
            } compactTrailing: {
                Text(context.attributes.word)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(maxWidth: 70)
            } minimal: {
                Image(systemName: "book.closed.fill").foregroundStyle(accent)
            }
            .widgetURL(URL(string: "verbum://word/\(context.attributes.wordID)"))
        }
    }
}
