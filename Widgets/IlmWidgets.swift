import SwiftUI
import WidgetKit

/// The app's widgets (owner 2026-11-26): «اسم اليوم وسنّة اليوم» on the home screen, and the lock screen's wide card
/// (a Live Activity, `IlmLiveActivity.swift`). The small lock screen widget was removed (owner 2026-11-27: its box
/// is too small — only these two places).
@main
struct IlmWidgets: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        TodayLiveActivity()
        if #available(iOS 18.0, *) {   // «مركز التحكم» (owner 2026-11-27): IlmControls.swift
            NameOfDayControl()
            SunnahOfDayControl()
        }
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
        completion(TodayEntry.make(Date(), Self.content(), WidgetSetup.load()))
    }

    /// Now, then every hour for two days: the name's next position (or the collection's next item) each hour, and the
    /// day's name and sunnah from each new day (UTC midnight — when the app's «اسم اليوم» changes).
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let c = Self.content()
        let choice = WidgetSetup.load()
        let now = Date()
        let first = Today.hourStart(now)
        var entries = [TodayEntry.make(now, c, choice)]
        for h in 1...48 { entries.append(TodayEntry.make(first.addingTimeInterval(Double(h) * 3600), c, choice)) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "today", provider: TodayProvider()) { entry in
            TodayHomeWidgetView(entry: entry)
        }
        .configurationDisplayName("اسم اليوم وسنّة اليوم")
        .description("يومًا اسمٌ من الأسماء الحسنى وآية من مواضعه، ويومًا سنّةٌ وثمرتها؛ أو مجموعة تختارها من «محفوظاتي» في «المزيد».")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
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
