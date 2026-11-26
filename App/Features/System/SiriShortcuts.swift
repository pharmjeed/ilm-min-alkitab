import AppIntents
import Foundation

/// «سيري» and the Shortcuts app (owner 2026-11-26 «سيري: ممتاز اعملها»): «اسم اليوم» and «سنّة اليوم» are spoken without
/// opening the app — the same name and sunnah as the widget and the reminders.
struct NameOfDayIntent: AppIntent {
    static var title: LocalizedStringResource = "اسم اليوم"
    static var description = IntentDescription("يقول لك اسم اليوم من الأسماء الحسنى ومعناه.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let n = Today.Content.app.name(Date()) else {
            return .result(dialog: "افتح علم من الكتاب مرة ليجهز المحتوى.")
        }
        let text = "اسم اليوم: \(n.name). \(NotificationText.body(n.excerpt, max: 220))"
        return .result(dialog: "\(text)")
    }
}

struct SunnahOfDayIntent: AppIntent {
    static var title: LocalizedStringResource = "سنّة اليوم"
    static var description = IntentDescription("يقول لك سنّة اليوم من برنامج اليوم والليلة وثمرتها.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let s = Today.Content.app.sunnah(Date()) else {
            return .result(dialog: "افتح علم من الكتاب مرة ليجهز المحتوى.")
        }
        let fruit = s.fruit.map { "، وثمرتها: \($0)" } ?? ""
        let text = "سنّة اليوم، \(s.time): \(s.todo)\(fruit)."
        return .result(dialog: "\(text)")
    }
}

struct IlmShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NameOfDayIntent(),
            phrases: [
                "اسم اليوم من \(.applicationName)",
                "\(.applicationName) اسم اليوم",
                "ما اسم اليوم في \(.applicationName)",
            ],
            shortTitle: "اسم اليوم",
            systemImageName: "sun.max")
        AppShortcut(
            intent: SunnahOfDayIntent(),
            phrases: [
                "سنة اليوم من \(.applicationName)",
                "\(.applicationName) سنة اليوم",
                "ما سنة اليوم في \(.applicationName)",
            ],
            shortTitle: "سنّة اليوم",
            systemImageName: "leaf")
    }
}
