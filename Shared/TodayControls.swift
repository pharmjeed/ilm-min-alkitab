import AppIntents
import Foundation

/// «مركز التحكم» (owner 2026-11-27): two buttons the reader can put in Control Center — or in place of the flashlight
/// or the camera at the bottom of the lock screen, or on the Action button — that open the app at the day's name or the
/// day's sunnah. The controls live in the widget extension (`Widgets/IlmControls.swift`); these intents open the app and
/// run inside it (`openAppWhenRun`), where `TodayControls.prepare()` set the hook.
enum TodayControlHook {
    /// "name" | "sunnah"
    nonisolated(unsafe) static var open: (@Sendable (String) async -> Void)?
}

struct OpenNameOfDayIntent: AppIntent {
    static var title: LocalizedStringResource = "افتح اسم اليوم"
    static var description = IntentDescription("يفتح اسم اليوم في «علم من الكتاب».")
    static var openAppWhenRun: Bool = true
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        await TodayControlHook.open?("name")
        return .result()
    }
}

struct OpenSunnahOfDayIntent: AppIntent {
    static var title: LocalizedStringResource = "افتح سنّة اليوم"
    static var description = IntentDescription("يفتح سنّة اليوم في «علم من الكتاب».")
    static var openAppWhenRun: Bool = true
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        await TodayControlHook.open?("sunnah")
        return .result()
    }
}
