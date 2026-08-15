import SwiftUI
import WidgetKit

struct TimeTapEntry: TimelineEntry {
    let date: Date
}

struct TimeTapProvider: TimelineProvider {
    func placeholder(in context: Context) -> TimeTapEntry {
        TimeTapEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (TimeTapEntry) -> Void) {
        completion(TimeTapEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimeTapEntry>) -> Void) {
        completion(Timeline(entries: [TimeTapEntry(date: Date())], policy: .never))
    }
}

struct TimeTapComplicationView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Text(family == .accessoryRectangular ? "timetap" : "TT")
            .containerBackground(for: .widget) {
                AccessoryWidgetBackground()
            }
    }
}

struct TimeTapComplication: Widget {
    let kind = "TimeTapComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimeTapProvider()) { _ in
            TimeTapComplicationView()
        }
        .supportedFamilies(Self.families)
    }

    private static var families: [WidgetFamily] {
        #if os(watchOS)
        [.accessoryCircular, .accessoryRectangular, .accessoryCorner]
        #else
        [.accessoryCircular, .accessoryRectangular]
        #endif
    }
}

@main
struct TimeTapWatchWidgets: WidgetBundle {
    var body: some Widget {
        TimeTapComplication()
    }
}
