import SwiftUI

@main
struct IlmApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "ar@numbers=latn"))
                .preferredColorScheme(AppSettings.colorScheme)
        }
    }
}

/// Small persisted settings. Launch arguments like `-onboarded YES` override UserDefaults (used by CI screenshots).
enum AppSettings {
    static var colorScheme: ColorScheme? {
        switch UserDefaults.standard.string(forKey: "appearance") ?? "dark" {
        case "light": return .light
        case "system": return nil
        default: return .dark
        }
    }
}

/// First launch → enable notifications (the only onboarding step). Afterwards → the tab shell.
struct RootView: View {
    @AppStorage("onboarded") private var onboarded = false

    var body: some View {
        if onboarded {
            MainTabView()
        } else {
            NotificationsOnboardingView { onboarded = true }
        }
    }
}

/// «الرئيسية · محفوظاتي · المزيد» — the two treasures are reached from «الرئيسية».
struct MainTabView: View {
    @StateObject private var nav = AppNav()

    var body: some View {
        TabView(selection: $nav.tab) {
            NavigationStack(path: $nav.homePath) { HomeView() }
                .tabItem { Label("الرئيسية", systemImage: "house") }
                .tag(0)
            NavigationStack { SavedView() }
                .tabItem { Label("محفوظاتي", systemImage: "bookmark") }
                .tag(1)
            NavigationStack { MoreView() }
                .tabItem { Label("المزيد", systemImage: "ellipsis.circle") }
                .tag(2)
        }
        .tint(Palette.gold(.dark))
        .environmentObject(nav)
    }
}

/// Tab selection and the «الرئيسية» stack, shared so pages can switch tab or jump back along the path.
final class AppNav: ObservableObject {
    @Published var tab: Int = Route.initialTab
    @Published var homePath: [HomeDestination] = Route.initialHomePath

    /// Opens a names page; if it is already in the stack (a crumb), pops back to it instead of pushing a copy.
    func open(_ route: NamesRoute) { open(dest: .n(route)) }
    func open(_ route: SunanRoute) { open(dest: .s(route)) }
    func open(dest d: HomeDestination) {
        if let i = homePath.lastIndex(of: d) {
            homePath.removeSubrange((i + 1)...)
        } else {
            homePath.append(d)
        }
    }
    /// Sibling pages (the previous / next time of «برنامج اليوم والليلة») replace the current page.
    func replaceLast(_ route: SunanRoute) {
        if !homePath.isEmpty { homePath.removeLast() }
        homePath.append(.s(route))
    }
}

/// Launch-argument routing for CI screenshots: `-route <name>` (see ci/routes.txt).
enum Route {
    static var arg: String { UserDefaults.standard.string(forKey: "route") ?? "home" }
    static var initialTab: Int {
        switch arg { case "saved": return 1; case "more": return 2; default: return 0 }
    }
    static var initialHomePath: [HomeDestination] {
        let firstSituation = NamesRepo.shared.door(1)?.situationIds.first ?? 1
        let feelSituation: [HomeDestination] = [.names, .n(.feel), .n(.door(1)), .n(.situation(firstSituation))]
        switch arg {
        case "names", "nod": return [.names]
        case "sunan": return [.sunan]
        case "feel": return [.names, .n(.feel)]
        case "door": return [.names, .n(.feel), .n(.door(1))]
        case "situation": return feelSituation
        case "nameinsit": return [.names, .n(.feel), .n(.door(1)), .n(.situation(1)), .n(.nameInSituation(name: 99, situation: 1))]
        case "name20": return [.names, .n(.name(20))]
        case "name20v", "savesheet": return [.names, .n(.name(20, focus: 1))]
        case "name20w": return [.names, .n(.name(20, tab: .sunnah, focus: 1))]
        case "name20pray": return [.names, .n(.name(20, tab: .pray))]
        case "name20sunnah": return [.names, .n(.name(20, tab: .sunnah))]
        case "name1": return [.names, .n(.name(1))]
        case "allnames": return [.names, .n(.allNames())]
        case "anfus": return [.names, .n(.feel), .n(.anfus())]
        case "ask": return [.names, .n(.ask())]
        // sunan section (ci/routes.txt `s…`)
        case "sdomain": return [.sunan, .s(.domain(1))]
        case "sneed": return [.sunan, .s(.domain(1)), .s(.need(1))]
        case "sstate": return [.sunan, .s(.domain(1)), .s(.need(1)), .s(.state(1))]
        case "sitem", "sitemtext", "sitemmore", "ssavesheet":
            return [.sunan, .s(.domain(1)), .s(.need(1)), .s(.state(1)), .s(.item(fp: "2c3521d318c6"))]
        case "sitemq", "sitemqtext":
            return [.sunan, .s(.domain(1)), .s(.need(1)), .s(.state(3)), .s(.item(fp: "b864df3937b5"))]
        case "sitemfp": return [.sunan, .s(.item(fp: "1c481e4cc3c2"))]
        case "sday": return [.sunan, .s(.day)]
        case "sdaytime": return [.sunan, .s(.day), .s(.dayTime(1))]
        case "sdeeds": return [.sunan, .s(.deeds)]
        case "sdeed": return [.sunan, .s(.deeds), .s(.deed(1))]
        case "smacro": return [.sunan, .s(.macro)]
        case "spairs": return [.sunan, .s(.pairs)]
        case "smethod": return [.sunan, .s(.method)]
        case "ssearch": return [.sunan, .s(.search(query: "رزق"))]
        default: return []
        }
    }

    /// `sitemtext` / `sitemqtext`: the item page scrolled to its full text, folds open; `sitemmore`: to «بمعناها».
    private static var sunanScrollPending: String? = {
        switch arg {
        case "sitemtext", "sitemqtext": return "text"
        case "sitemmore": return "more"
        default: return nil
        }
    }()
    static func consumeSunanScroll() -> String? {
        defer { sunanScrollPending = nil }
        return sunanScrollPending
    }
    static var sunanOpenFolds: Bool { ["sitemtext", "sitemqtext"].contains(arg) }
    /// `nod`: the names home scrolled to «اسم اليوم».
    static var scrollToNameOfDay: Bool { arg == "nod" }
    /// `name20pray` / `name20sunnah` / `name1`: the name page scrolled to its tabs.
    static var scrollToTabs: Bool { ["name20pray", "name20sunnah", "name1"].contains(arg) }

    /// `savesheet`: the first «مفضلة» on the page opens the sign-in sheet once.
    private static var autoSaveSheetPending = arg == "savesheet" || arg == "ssavesheet"
    static func consumeAutoSaveSheet() -> Bool {
        guard autoSaveSheetPending else { return false }
        autoSaveSheetPending = false
        return true
    }
}
