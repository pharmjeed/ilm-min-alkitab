import ActivityKit
import Foundation

/// «العرض الكبير على شاشة القفل» (owner 2026-11-26), switched on in «المزيد»: starts the day's card (a Live Activity)
/// when the app comes to the front — once a day, so a card the reader swiped away or ended with «تمّت» does not come
/// back until the next day. iOS only lets an app start one while it is in front (or by a push from a server), keeps
/// it active for about 8 hours and removes it from the lock screen 4 hours later.
@MainActor
enum LiveToday {
    static let key = "live.enabled"
    private static let shownKey = "live.shown.day"

    /// «تمّت» on the card runs inside the app: call once at launch.
    nonisolated static func prepare() {
        TodayActivityHook.done = { await LiveToday.end() }
    }

    /// What the card shows: the day's sunnah with its result; the day's name when there is no sunnah.
    static func state(_ c: Today.Content, _ now: Date) -> TodayActivityAttributes.ContentState? {
        if let s = c.sunnah(now) {
            return TodayActivityAttributes.ContentState(header: "سنّة اليوم", title: s.todo, serif: false,
                                                        line: s.fruit.map { "← \($0)" }, green: true,
                                                        link: Today.link(s).absoluteString)
        }
        if let n = c.name(now) {
            return TodayActivityAttributes.ContentState(header: "اسم اليوم", title: n.name, serif: true,
                                                        line: NotificationText.body(n.excerpt, max: 90), green: false,
                                                        link: Today.link(n).absoluteString)
        }
        return nil
    }

    /// The app came to the front, or the switch changed (`byUser`: start it even if it was shown today).
    static func refresh(byUser: Bool = false, now: Date = Date()) async {
        let d = UserDefaults.standard
        let day = Today.dayNumber(now)
        let running = Activity<TodayActivityAttributes>.activities
        guard d.bool(forKey: key), ActivityAuthorizationInfo().areActivitiesEnabled, let s = state(.app, now) else {
            for a in running { await a.end(nil, dismissalPolicy: .immediate) }
            return
        }
        let content = ActivityContent(state: s, staleDate: nil)
        if let a = running.first(where: { $0.attributes.day == day && $0.activityState == .active }) {
            if a.content.state != s { await a.update(content) }
            return
        }
        // yesterday's card
        for a in running { await a.end(nil, dismissalPolicy: .immediate) }
        let shownToday = d.object(forKey: shownKey) != nil && d.integer(forKey: shownKey) == day
        guard byUser || !shownToday else { return }
        if (try? Activity<TodayActivityAttributes>.request(attributes: TodayActivityAttributes(day: day), content: content, pushType: nil)) != nil {
            d.set(day, forKey: shownKey)
        }
    }

    static func end() async {
        for a in Activity<TodayActivityAttributes>.activities { await a.end(nil, dismissalPolicy: .immediate) }
    }
}
