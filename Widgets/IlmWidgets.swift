import SwiftUI
import WidgetKit

/// The app's widgets (owner 2026-11-26): «اسم اليوم وسنّة اليوم» on the home screen, «اسم اليوم» on the lock screen.
@main
struct IlmWidgets: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        TodayLockWidget()
    }
}

struct TodayProvider: TimelineProvider {
    /// The two small pack files the extension carries (`index.pack`, `day.pack`); else the app's bundled packs.
    static func content() -> Today.Content {
        let own = Bundle.main
        let app = own.bundleURL.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("packs")
        let names = own.url(forResource: "index", withExtension: "pack") ?? app.appendingPathComponent("names/index.pack")
        let day = own.url(forResource: "day", withExtension: "pack") ?? app.appendingPathComponent("sunan/day.pack")
        return Today.Content.load(names: names, day: day)
    }

    func placeholder(in context: Context) -> TodayEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(TodayEntry.make(Date(), Self.content()))
    }

    /// Now, then each new day (UTC midnight — when the app's «اسم اليوم» changes) for a week.
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let c = Self.content()
        var dates = [Date()]
        for _ in 0..<7 { dates.append(Today.nextDay(after: dates[dates.count - 1])) }
        completion(Timeline(entries: dates.map { TodayEntry.make($0, c) }, policy: .atEnd))
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "today", provider: TodayProvider()) { entry in
            TodayHomeWidgetView(entry: entry)
        }
        .configurationDisplayName("اسم اليوم وسنّة اليوم")
        .description("يومًا اسمٌ من الأسماء الحسنى ومعناه، ويومًا سنّةٌ وثمرتها؛ والزر يبدّل بينهما.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct TodayLockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "today-lock", provider: TodayProvider()) { entry in
            TodayLockWidgetView(entry: entry)
        }
        .configurationDisplayName("اسم اليوم")
        .description("اسم اليوم وسطرٌ من معناه على شاشة القفل.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}

private struct TodayHomeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry
    var body: some View {
        TodayWidgetView(entry: entry, family: family)
            .environment(\.layoutDirection, .rightToLeft)
    }
}

private struct TodayLockWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry
    var body: some View {
        TodayWidgetView(entry: entry, family: family)
            .environment(\.layoutDirection, .rightToLeft)
    }
}
