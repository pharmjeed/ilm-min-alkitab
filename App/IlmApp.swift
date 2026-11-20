import SwiftUI

@main
struct IlmApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "ar"))
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
    @State private var tab = Route.initialTab
    @State private var homePath: [HomeDestination] = Route.initialHomePath

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack(path: $homePath) { HomeView() }
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
    }
}

/// Launch-argument routing for CI screenshots: `-route home|saved|more|names|sunan`.
enum Route {
    static var arg: String { UserDefaults.standard.string(forKey: "route") ?? "home" }
    static var initialTab: Int {
        switch arg { case "saved": return 1; case "more": return 2; default: return 0 }
    }
    static var initialHomePath: [HomeDestination] {
        switch arg { case "names": return [.names]; case "sunan": return [.sunan]; default: return [] }
    }
}
