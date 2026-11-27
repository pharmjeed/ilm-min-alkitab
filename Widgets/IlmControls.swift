import AppIntents
import SwiftUI
import WidgetKit

/// «مركز التحكم» (owner 2026-11-27): «اسم اليوم» and «سنّة اليوم» as Control Center buttons (iOS 18+). The reader adds
/// them from Control Center's edit mode, or puts one in place of the flashlight / camera on the lock screen.
@available(iOS 18.0, *)
struct NameOfDayControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "control.name") {
            ControlWidgetButton(action: OpenNameOfDayIntent()) {
                Label("اسم اليوم", systemImage: "sparkles")
            }
        }
        .displayName("اسم اليوم")
        .description("يفتح اسم اليوم في «علم من الكتاب».")
    }
}

@available(iOS 18.0, *)
struct SunnahOfDayControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "control.sunnah") {
            ControlWidgetButton(action: OpenSunnahOfDayIntent()) {
                Label("سنّة اليوم", systemImage: "moon.stars")
            }
        }
        .displayName("سنّة اليوم")
        .description("يفتح سنّة اليوم في «علم من الكتاب».")
    }
}
