import WidgetKit
import SwiftUI

@main
struct VerbumWidgetBundle: WidgetBundle {
    var body: some Widget {
        VerbumWidget()
        VerbumWidgetMedium()
        VerbumLockScreenWidget()
        WordOfDayWidget()
    }
}
