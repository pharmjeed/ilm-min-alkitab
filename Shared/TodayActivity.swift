import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// «العرض الكبير على شاشة القفل» (owner 2026-11-26): the day's sunnah on a card as wide as the screen — a Live
/// Activity, the only wide thing Apple allows there (the lock screen's widget box is about 160×72 points). The app
/// starts it (`LiveToday`); the widget extension draws it (`TodayLiveActivity`).
struct TodayActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// «سنّة اليوم» / «اسم اليوم»
        var header: String
        var title: String
        /// a name is set in the display serif
        var serif: Bool
        /// the sunnah's result (green), or a line of the name's meaning
        var line: String?
        var green: Bool
        /// what a tap opens: ilm://…
        var link: String?
    }

    /// The website's day it was started for (`Today.dayNumber`).
    var day: Int
}

/// «تمّت»: ends the card for today. A LiveActivityIntent runs inside the app, where `LiveToday` set the hook.
struct TodayDoneIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "تمّت سنّة اليوم"
    static var isDiscoverable: Bool = false
    func perform() async throws -> some IntentResult {
        await TodayActivityHook.done?()
        return .result()
    }
}

enum TodayActivityHook {
    nonisolated(unsafe) static var done: (@Sendable () async -> Void)?
}

/// The card: on the lock screen, and the Dynamic Island's expanded view. At most about 160 points high (the system's
/// limit): two lines of the sunnah and two of its result.
struct TodayLiveView: View {
    let state: TodayActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 6) {
                Text(state.header).font(WidgetLook.sans(13, .medium)).foregroundStyle(WidgetLook.gold).lineLimit(1)
                Spacer(minLength: 4)
                Button(intent: TodayDoneIntent()) {
                    Text("تمّت")
                        .font(WidgetLook.sans(12, .bold)).foregroundStyle(WidgetLook.night)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(WidgetLook.gold, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            Text(state.title)
                .font(state.serif ? WidgetLook.serif(26) : WidgetLook.sans(17, .bold))
                .foregroundStyle(WidgetLook.cream).lineSpacing(3).lineLimit(2).minimumScaleFactor(0.7)
            if let line = state.line, !line.isEmpty {
                Text(line)
                    .font(WidgetLook.sans(14, .medium))
                    .foregroundStyle(state.green ? WidgetLook.green : WidgetLook.cream.opacity(0.85))
                    .lineSpacing(3).lineLimit(2).minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        .environment(\.layoutDirection, .rightToLeft)
    }
}
