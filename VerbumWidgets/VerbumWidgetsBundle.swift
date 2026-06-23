import WidgetKit
import SwiftUI

/// Widget extension entry point. Hosts the word-spotlight Live Activity (Dynamic Island /
/// Lock Screen). Home-screen widgets can be added here later.
@main
struct VerbumWidgetsBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.2, *) {
            WordSpotlightLiveActivity()
        }
    }
}
