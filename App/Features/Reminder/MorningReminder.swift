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

/// «تذكير المساء» (owner 2026-11-26: «إشعار هادئ مرة أو مرتين في اليوم»): «سنّة اليوم» of «برنامج اليوم والليلة» — the
/// same sunnah as the home widget — at the chosen time (default 21:00), opening its page.
enum EveningReminder {
    static let idPrefix = "evening-"

    private static var d: UserDefaults { .standard }
    static var enabled: Bool { d.object(forKey: "evening.enabled") == nil ? true : d.bool(forKey: "evening.enabled") }
    static var hour: Int { d.object(forKey: "evening.hour") == nil ? 21 : d.integer(forKey: "evening.hour") }
    static var minute: Int { d.object(forKey: "evening.minute") == nil ? 0 : d.integer(forKey: "evening.minute") }

    struct Planned {
        let id: String
        let fire: Date
        let sunnah: Today.Sunnah
        var title: String { "سنّة اليوم · \(sunnah.time)" }
        var body: String { sunnah.fruit.map { "\(sunnah.todo) ← \($0)" } ?? sunnah.todo }
        var userInfo: [AnyHashable: Any] { ["route": "sunnah", "fp": sunnah.fp, "stateId": sunnah.stateId] }
    }

    /// The next `MorningReminder.windowDays` evenings after `now`.
    static func plan(from now: Date = Date(), calendar: Calendar = .current) -> [Planned] {
        let content = Today.Content.app
        var out: [Planned] = []
        let today = calendar.startOfDay(for: now)
        let g = Calendar(identifier: .gregorian)
        for offset in 0...MorningReminder.windowDays {
            guard out.count < MorningReminder.windowDays,
                  let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let fire = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  fire > now,
                  let s = content.sunnah(fire) else { continue }
            let c = g.dateComponents(in: calendar.timeZone, from: fire)
            let id = idPrefix + String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
            out.append(Planned(id: id, fire: fire, sunnah: s))
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
        let old = await center.pendingNotificationRequests().map(\.identifier)
            .filter { $0.hasPrefix(MorningReminder.idPrefix) || $0.hasPrefix(EveningReminder.idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: old)
        let status = await center.notificationSettings().authorizationStatus
        guard MorningReminder.allowed(status) else { return 0 }
        var n = 0
        func add(_ id: String, _ title: String, _ body: String, _ info: [AnyHashable: Any], _ fire: Date, _ thread: String) async {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.threadIdentifier = thread
            content.userInfo = info
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            do {
                try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
                n += 1
            } catch {}
        }
        // 30 mornings + 30 evenings stay under iOS's 64 pending notifications
        if MorningReminder.enabled {
            for p in MorningReminder.plan() { await add(p.id, p.title, p.body, p.userInfo, p.fire, "morning") }
        }
        if EveningReminder.enabled {
            for p in EveningReminder.plan() { await add(p.id, p.title, p.body, p.userInfo, p.fire, "evening") }
        }
        return n
    }
}

// NotificationText (the shortened excerpt) lives in Shared/Today.swift — the widget uses it too.

/// Notification taps → the name or sunnah page (cold start included: the request waits until the tab shell consumes it).
final class NotificationRouter: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()

    struct Open: Equatable {
        let token = UUID()
        let target: Target
    }

    /// Where a tap leads: the name page (morning), the sunnah page (evening).
    enum Target: Equatable {
        case name(Int)
        case sunnah(fp: String, stateId: Int)
    }

    @Published var pending: Open?

    private static func int(_ v: Any?) -> Int? { (v as? Int) ?? (v as? NSNumber)?.intValue }

    static func nameId(_ info: [AnyHashable: Any]) -> Int? {
        guard (info["route"] as? String) == "name" else { return nil }
        return int(info["nameId"])
    }

    static func target(_ info: [AnyHashable: Any]) -> Target? {
        if let id = nameId(info) { return .name(id) }
        if (info["route"] as? String) == "sunnah", let fp = info["fp"] as? String, let st = int(info["stateId"]) {
            return .sunnah(fp: fp, stateId: st)
        }
        return nil
    }

    func open(userInfo: [AnyHashable: Any]) {
        guard let t = Self.target(userInfo) else { return }
        Task { @MainActor in self.pending = Open(target: t) }
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
