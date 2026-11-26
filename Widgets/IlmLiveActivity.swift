import ActivityKit
import SwiftUI
import WidgetKit

/// The lock screen's wide card and its Dynamic Island views (owner 2026-11-26) — see `Shared/TodayActivity.swift`.
struct TodayLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TodayActivityAttributes.self) { context in
            TodayLiveView(state: context.state)
                .padding(16)
                .activityBackgroundTint(WidgetLook.night)
                .activitySystemActionForegroundColor(WidgetLook.gold)
                .widgetURL(context.state.link.flatMap { URL(string: $0) })
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    TodayLiveView(state: context.state)
                }
            } compactLeading: {
                Image(systemName: "moon.stars.fill").foregroundStyle(WidgetLook.gold)
            } compactTrailing: {
                Text(context.state.header).font(WidgetLook.sans(12, .medium)).foregroundStyle(WidgetLook.gold)
                    .lineLimit(1)
            } minimal: {
                Image(systemName: "moon.stars.fill").foregroundStyle(WidgetLook.gold)
            }
            .widgetURL(context.state.link.flatMap { URL(string: $0) })
        }
    }
}
