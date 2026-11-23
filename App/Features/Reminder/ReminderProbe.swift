import SwiftUI
import UserNotifications

/// CI only (`-route notif -ciNotify YES` / `-route notiftap -ciNotify YES`): the simulator cannot answer the permission
/// dialog, so it asks for quiet (provisional) permission, schedules the real window, and shows what is pending —
/// `notif` as an overlay with the first notifications (plus a live banner of the first one), `notiftap` by opening the
/// page a tap on the first one opens. Never runs without the launch argument.
struct ReminderProbe {
    struct Item: Identifiable {
        let id: String
        let when: String
        let title: String
        let body: String
    }
    let count: Int
    let items: [Item]

    @MainActor
    static func runIfRequested() async -> ReminderProbe? {
        guard UserDefaults.standard.bool(forKey: "ciNotify"), ["notif", "notiftap"].contains(Route.arg) else { return nil }
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.provisional, .alert, .sound])
        let count = await ReminderScheduler.shared.reschedule().value
        let pending = await center.pendingNotificationRequests()
            .filter { $0.identifier.hasPrefix(MorningReminder.idPrefix) }
            .sorted { $0.identifier < $1.identifier }
        if Route.arg == "notiftap" {
            if let first = pending.first { NotificationRouter.shared.open(userInfo: first.content.userInfo) }
            return nil
        }
        if let first = pending.first {
            let banner = UNNotificationRequest(identifier: "ci-preview", content: first.content,
                                               trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1.5, repeats: false))
            try? await center.add(banner)
        }
        let items = pending.prefix(2).map { r -> Item in
            let date = (r.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
            return Item(id: r.identifier, when: date.map(ArabicDate.dayAndTime) ?? "—",
                        title: r.content.title, body: r.content.body)
        }
        return ReminderProbe(count: count, items: Array(items))
    }
}

struct ReminderProbeView: View {
    let probe: ReminderProbe
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        VStack(alignment: .leading, spacing: 8) {
            Text("فحص الإشعارات (البناء السحابي فقط)").font(AppFont.sans(12)).foregroundStyle(t.muted)
            Text("مجدول: \(Arabic.count(probe.count, ArabicDate.notifications))").font(AppFont.sans(15, .bold)).foregroundStyle(t.gold)
            ForEach(probe.items) { it in
                Text(it.when).font(AppFont.sans(12)).foregroundStyle(t.muted)
                NotificationPreview(title: it.title, message: it.body)
            }
        }
        .padding(12)
        .background(t.bg.opacity(0.96), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(t.gold.opacity(0.5), lineWidth: 1))
        .padding(.horizontal, 10)
    }
}

/// Gregorian dates and times in Arabic words with Western digits («24 نوفمبر 2026»، «7:00 ص»).
enum ArabicDate {
    static let months = ["يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو",
                         "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"]
    static let notifications = Arabic.CountForms(one: "إشعار واحد", two: "إشعاران", few: "إشعارات", many: "إشعارًا")

    private static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }

    static func day(_ d: Date, year: Bool = true) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: d)
        let m = months[((c.month ?? 1) - 1 + 12) % 12]
        return year ? "\(c.day ?? 1) \(m) \(c.year ?? 0)" : "\(c.day ?? 1) \(m)"
    }

    static func time(_ d: Date) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: d)
        let h = c.hour ?? 0
        let h12 = h % 12 == 0 ? 12 : h % 12
        return String(format: "%d:%02d", h12, c.minute ?? 0) + (h < 12 ? " ص" : " م")
    }

    static func dayAndTime(_ d: Date) -> String { "\(day(d)) · \(time(d))" }

    /// «اليوم 9:41 ص» · «أمس 8:00 م» · «20 نوفمبر 2026 · 8:00 م».
    static func relative(_ d: Date, now: Date = Date()) -> String {
        if calendar.isDate(d, inSameDayAs: now) { return "اليوم \(time(d))" }
        if let y = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(d, inSameDayAs: y) { return "أمس \(time(d))" }
        return dayAndTime(d)
    }

    /// ISO-8601 (`2026-11-23T20:20:15Z`, fractions allowed).
    static func parseISO(_ s: String?) -> Date? {
        guard let s else { return nil }
        let f = ISO8601DateFormatter()
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: s)
    }
}
