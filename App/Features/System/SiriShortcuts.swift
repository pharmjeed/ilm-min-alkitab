import AppIntents
import SwiftUI

/// «سيري» and the Shortcuts app (owner 2026-11-26): «اسم اليوم» / «سنّة اليوم» (the same as the widget), and — «اجعله يقول
/// اي سنة واي اسم مع الموضع بشكل عشوائي» — a name with one of its positions, or a sunnah, picked at random.
/// Siri says the name and where its ayah is; the ayah itself is shown on the card, verbatim, not read by the voice.
struct NameOfDayIntent: AppIntent {
    static var title: LocalizedStringResource = "اسم اليوم"
    static var description = IntentDescription("يقول لك اسم اليوم من الأسماء الحسنى ويعرض آية من مواضعه.")

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let n = Today.Content.app.name(Date())
        let v = n.flatMap { Today.verse(of: $0.id, slot: Today.hourNumber(Date())) }
        return .result(dialog: "\(SiriText.name(n, v, prefix: "اسم اليوم"))", view: NameSnippet(name: n, verse: v))
    }
}

struct SunnahOfDayIntent: AppIntent {
    static var title: LocalizedStringResource = "سنّة اليوم"
    static var description = IntentDescription("يقول لك سنّة اليوم من برنامج اليوم والليلة وثمرتها.")

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let s = Today.Content.app.sunnah(Date())
        return .result(dialog: "\(SiriText.sunnah(s, prefix: "سنّة اليوم"))", view: SunnahSnippet(sunnah: s))
    }
}

struct RandomNameIntent: AppIntent {
    static var title: LocalizedStringResource = "اسم من الأسماء الحسنى"
    static var description = IntentDescription("يختار لك اسمًا من الأسماء الحسنى وموضعًا من مواضعه في القرآن.")

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let c = Today.Content.app
        let n = c.names?.names.randomElement().flatMap { c.name(id: $0.id) }
        let v = n.flatMap { Today.verses(of: $0.id).randomElement() }
        return .result(dialog: "\(SiriText.name(n, v, prefix: "اسم الله"))", view: NameSnippet(name: n, verse: v))
    }
}

struct RandomSunnahIntent: AppIntent {
    static var title: LocalizedStringResource = "سنّة من السنن"
    static var description = IntentDescription("يختار لك سنّةً من «السنن والأسباب» وثمرتها.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let s = await SiriText.randomSunnah()
        return .result(dialog: "\(SiriText.sunnah(s, prefix: "سنّة"))", view: SunnahSnippet(sunnah: s))
    }
}

struct IlmShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RandomNameIntent(),
            phrases: [
                "اسم من \(.applicationName)",
                "أعطني اسما من \(.applicationName)",
                "اسم من أسماء الله من \(.applicationName)",
            ],
            shortTitle: "اسم وموضعه",
            systemImageName: "sparkles")
        AppShortcut(
            intent: RandomSunnahIntent(),
            phrases: [
                "سنة من \(.applicationName)",
                "أعطني سنة من \(.applicationName)",
                "ذكرني بسنة من \(.applicationName)",
            ],
            shortTitle: "سنّة",
            systemImageName: "leaf.fill")
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
        AppShortcut(
            intent: NameWallpaperIntent(),
            phrases: ["خلفية من \(.applicationName)"],
            shortTitle: "خلفية اسم اليوم",
            systemImageName: "photo")
    }
}

/// What Siri says.
enum SiriText {
    static let notReady = "افتح علم من الكتاب مرة ليجهز المحتوى."

    static func name(_ n: Today.Name?, _ v: Today.Verse?, prefix: String) -> String {
        guard let n else { return notReady }
        guard let v else { return "\(prefix): \(n.name). \(NotificationText.body(n.excerpt, max: 220))" }
        let ayahs = v.last.map { "الآيات \(v.a) إلى \($0)" } ?? "الآية \(v.a)"
        return "\(prefix): \(n.name). ومن مواضعه سورة \(v.surah)، \(ayahs)."
    }

    static func sunnah(_ s: Today.Sunnah?, prefix: String) -> String {
        guard let s else { return notReady }
        let fruit = s.fruit.map { "، وثمرتها: \($0)" } ?? ""
        return "\(prefix): \(s.todo)\(fruit)."
    }

    /// Any sunnah of «السنن والأسباب»: a state at random, then one of its sunan (a group's representative).
    @MainActor
    static func randomSunnah() async -> Today.Sunnah? {
        let states = (SunanRepo.shared.index?.states ?? []).filter { $0.counts.items > 0 }
        for _ in 0..<4 {
            guard let st = states.randomElement(), let items = try? await SunanStore.shared.stateItems(st.id) else { continue }
            guard let it = items.filter({ $0.repOf == nil }).randomElement() ?? items.randomElement() else { continue }
            let parts = it.easy.components(separatedBy: "←")
            let todo = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let fruit = parts.dropFirst().joined(separator: "←").trimmingCharacters(in: .whitespacesAndNewlines)
            return Today.Sunnah(fp: it.fp, stateId: it.stateId, time: st.title, todo: todo,
                                fruit: fruit.isEmpty ? nil : fruit, grade: it.grade, source: it.srcLabel ?? it.ref)
        }
        return nil
    }
}

/// The card under Siri's answer: the name, its ayah whole (Amiri) with its reference, and a line of its meaning.
struct NameSnippet: View {
    let name: Today.Name?
    let verse: Today.Verse?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let n = name {
                Text(n.name).font(WidgetLook.serif(26)).foregroundStyle(WidgetLook.gold)
                if let v = verse {
                    Text(ayah(v)).lineSpacing(4)
                }
                Text(NotificationText.body(n.excerpt, max: 160)).font(WidgetLook.sans(14)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func ayah(_ v: Today.Verse) -> AttributedString {
        var a = AttributedString("﴿\(v.text)﴾")
        a.font = WidgetLook.amiri(19)
        var r = AttributedString(" \(v.ref.nonBreaking)")
        r.font = WidgetLook.sans(12)
        r.foregroundColor = .secondary
        return a + r
    }
}

struct SunnahSnippet: View {
    let sunnah: Today.Sunnah?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let s = sunnah {
                if !s.time.isEmpty { Text(s.time).font(WidgetLook.sans(13)).foregroundStyle(.secondary) }
                Text(s.todo).font(WidgetLook.sans(18, .bold))
                if let f = s.fruit {
                    Text("← \(f)").font(WidgetLook.sans(16, .medium)).foregroundStyle(Color(red: 0.18, green: 0.55, blue: 0.36))
                }
                let meta = [s.grade, s.source].compactMap { $0 }.joined(separator: " · ")
                if !meta.isEmpty { Text(meta).font(WidgetLook.sans(12)).foregroundStyle(.secondary) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .environment(\.layoutDirection, .rightToLeft)
    }
}
