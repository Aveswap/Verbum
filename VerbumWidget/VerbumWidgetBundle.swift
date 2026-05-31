import WidgetKit
import SwiftUI

@main
struct VerbumWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Home-screen (small/medium/large): real, language-aware timeline from the App Group.
        WordOfDayWidget()
        // Lock-screen (rectangular/inline): same App Group source.
        VerbumLockScreenWidget()
    }
}
