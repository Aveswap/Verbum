import ActivityKit
import WidgetKit
import SwiftUI

/// Rush-challenge Live Activity: 60-second countdown + live score, pinned to the Lock Screen and
/// Dynamic Island while the player is in a Rush run. Self-contained styling so the widget
/// extension stays lean — it only needs ActivityKit + WidgetKit + the shared RushActivityAttributes.
@available(iOSApplicationExtension 16.2, *)
struct RushChallengeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RushActivityAttributes.self) { context in
            // Lock Screen / notification-banner presentation.
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.title2)
                    .foregroundColor(.cyan)
                VStack(alignment: .leading) {
                    Text("Rush")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(timerInterval: Date.now...context.state.endDate, countsDown: true)
                        .font(.title)
                        .bold()
                }
                Spacer()
                Text("\(context.state.score)")
                    .font(.title)
                    .bold()
                    .foregroundColor(.cyan)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "bolt.fill").foregroundColor(.cyan)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.score)")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.cyan)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(timerInterval: Date.now...context.state.endDate, countsDown: true)
                        .font(.largeTitle)
                        .bold()
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            } compactLeading: {
                Image(systemName: "bolt.fill").foregroundColor(.cyan)
            } compactTrailing: {
                Text(timerInterval: Date.now...context.state.endDate, countsDown: true)
                    .frame(maxWidth: 44)
            } minimal: {
                // While the owning app is foregrounded, iOS often falls back to the minimal
                // presentation — show the live timer here so the user always sees the
                // countdown in the Dynamic Island, not just a static icon.
                Text(timerInterval: Date.now...context.state.endDate, countsDown: true)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.cyan)
                    .frame(maxWidth: 36)
            }
        }
    }
}
