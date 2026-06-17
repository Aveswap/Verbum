import WidgetKit
import SwiftUI

struct WordOfDayWidget: Widget {
    let kind = "VerbumWordOfTheDay"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WordOfDayProvider()) { entry in
            if #available(iOS 17.0, *) {
                WordOfDayEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        LinearGradient(
                            colors: [Color(hex: "#0F1F25"), Color(hex: "#1A2F38")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
            } else {
                WordOfDayEntryView(entry: entry)
            }
        }
        .configurationDisplayName("Word of the Day")
        .description("A fresh word through the day — tap to open and learn it.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
