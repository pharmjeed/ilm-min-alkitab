import Foundation
import UserNotifications

/// «تذكير الصباح»: a rolling window of local notifications, one a day at the chosen time (default 07:00), each naming
/// that day's «اسم اليوم» — the website's rule evaluated at the moment it fires — and opening its page.
/// Rescheduled at launch / return to the app, when the time or the switch changes, and after a content update.
enum MorningReminder {
    static let idPrefix = "morning-"
    static let windowDays = 30

    private static var d: UserDefaults { .standard }
    static var enabled: Bool { d.object(forKey: "reminder.enabled") == nil ? true : d.bool(forKey: "reminder.enabled") }
    static var hour: Int { d.object(forKey: "reminder.hour") == nil ? 7 : d.integer(forKey: "reminder.hour") }
    static var minute: Int { d.object(forKey: "reminder.minute") == nil ? 0 : d.integer(forKey: "reminder.minute") }

    static func allowed(_ s: UNAuthorizationStatus) -> Bool {
        switch s {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }

    struct Planned {
        let id: String
        let fire: Date
        let card: NameCard
        var title: String { "اسم اليوم: \(card.name)" }
        var body: String { NotificationText.body(card.excerpt) }
        var userInfo: [AnyHashable: Any] { ["route": "name", "nameId": card.id] }
    }

    /// The next `windowDays` mornings after `now`.
    static func plan(from now: Date = Date(), calendar: Calendar = .current) -> [Planned] {
        var out: [Planned] = []
        let today = calendar.startOfDay(for: now)
        let g = Calendar(identifier: .gregorian)
        for offset in 0...windowDays {
            guard out.count < windowDays,
                  let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let fire = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  fire > now,
                  let card = NamesRepo.shared.nameOfDay(fire) else { continue }
            let c = g.dateComponents(in: calendar.timeZone, from: fire)
            let id = idPrefix + String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
            out.append(Planned(id: id, fire: fire, card: card))
        }
        return out
    }
}

/// Serialises rescheduling (each run removes the window and adds it again).
@MainActor
final class ReminderScheduler {
    static let shared = ReminderScheduler()
    private var last: Task<Int, Never>?

    /// Returns the number of morning notifications now pending.
    @discardableResult
    func reschedule() -> Task<Int, Never> {
        let previous = last
        let task: Task<Int, Never> = Task {
            _ = await previous?.value
            return await ReminderScheduler.apply()
        }
        last = task
        return task
    }

    nonisolated private static func apply() async -> Int {
        let center = UNUserNotificationCenter.current()
        let old = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(MorningReminder.idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: old)
        let status = await center.notificationSettings().authorizationStatus
        guard MorningReminder.enabled, MorningReminder.allowed(status) else { return 0 }
        var n = 0
        for p in MorningReminder.plan() {
            let content = UNMutableNotificationContent()
            content.title = p.title
            content.body = p.body
            content.sound = .default
            content.threadIdentifier = "morning"
            content.userInfo = p.userInfo
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: p.fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            do {
                try await center.add(UNNotificationRequest(identifier: p.id, content: content, trigger: trigger))
                n += 1
            } catch {}
        }
        return n
    }
}

/// The notification text: the name's excerpt from the pack, verbatim, at most `max` characters (Unicode scalars, as
/// the website counts). A cut never falls inside an ayah: the excerpt is cut before its «﴿» or keeps the whole ayah.
enum NotificationText {
    static let fallback = "افتح لتقرأ معنى الاسم، ومتى تدعو به."
    private static let trailing: Set<Unicode.Scalar> = [":", "،", "؛", "—", "–", "-", ",", "."]

    static func body(_ excerpt: String, max: Int = 140) -> String {
        let s = Array(excerpt.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars)
        let n = s.count
        // ayah spans: consecutive ornate brackets (open, close); an unclosed one runs to the end
        let brackets = s.indices.filter { s[$0] == "\u{FD3F}" || s[$0] == "\u{FD3E}" }
        var spans: [(Int, Int)] = []
        var k = 0
        while k < brackets.count {
            spans.append((brackets[k], k + 1 < brackets.count ? brackets[k + 1] : n))
            k += 2
        }
        let complete = spans.allSatisfy { $0.1 < n }
        if n <= max && complete { return String(String.UnicodeScalarView(s)) }
        let starts = Set(spans.map(\.0))
        let ends = Set(spans.map(\.1))
        func splits(_ c: Int) -> Bool { spans.contains { $0.0 < c && c <= $0.1 } }
        func boundary(_ c: Int) -> Bool {
            c >= n || s[c].properties.isWhitespace || s[c - 1].properties.isWhitespace
                || starts.contains(c) || ends.contains(c - 1)
        }
        var cut = Swift.min(n, max - 1)
        while cut > 0 && (splits(cut) || !boundary(cut)) { cut -= 1 }
        var head = Array(s[0..<cut])
        while let last = head.last, last.properties.isWhitespace || trailing.contains(last) { head.removeLast() }
        guard !head.isEmpty else { return fallback }
        return String(String.UnicodeScalarView(head)) + "…"
    }
}

/// Notification taps → the name page (cold start included: the request waits until the tab shell consumes it).
final class NotificationRouter: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()

    struct Open: Equatable {
        let token = UUID()
        let nameId: Int
    }

    @Published var pending: Open?

    static func nameId(_ info: [AnyHashable: Any]) -> Int? {
        guard (info["route"] as? String) == "name" else { return nil }
        if let i = info["nameId"] as? Int { return i }
        return (info["nameId"] as? NSNumber)?.intValue
    }

    func open(userInfo: [AnyHashable: Any]) {
        guard let id = Self.nameId(userInfo) else { return }
        Task { @MainActor in self.pending = Open(nameId: id) }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        open(userInfo: response.notification.request.content.userInfo)
        completionHandler()
    }

    /// The morning notification also shows while the app is open.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}
