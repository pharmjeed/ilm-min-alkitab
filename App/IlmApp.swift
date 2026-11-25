import SwiftUI
import UIKit
import UserNotifications

@main
struct IlmApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // before any pack is read: apply a version that finished downloading last time, drop stale downloads
        PackStore.prepareAtLaunch()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "ar@numbers=latn"))
        }
    }
}

/// The notification delegate must be set before launch finishes, so a tap that launched the app is delivered.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = NotificationRouter.shared
        return true
    }
}

/// First launch → enable notifications (the only onboarding step). Afterwards → the tab shell.
/// Launch arguments like `-onboarded YES` / `-appearance light` override UserDefaults (CI screenshots).
struct RootView: View {
    @AppStorage("onboarded") private var onboarded = false
    @AppStorage("appearance") private var appearance = Appearance.dark.rawValue
    @Environment(\.scenePhase) private var phase
    /// The opening shot plays on every launch (not in CI screenshots, except the `splash` route).
    @State private var splashDone = Route.isCI && Route.arg != "splash"

    var body: some View {
        ZStack {
            Group {
                if onboarded {
                    MainTabView()
                } else {
                    NotificationsOnboardingView(ready: splashDone) { onboarded = true }
                }
            }
            if !splashDone {
                SplashView(hold: Route.arg == "splash") {
                    withAnimation(.easeOut(duration: 0.35)) { splashDone = true }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .preferredColorScheme(Appearance.from(appearance).scheme)
        .onAppear { Appearance.apply(Appearance.from(appearance)) }
        .onChange(of: appearance) { _, v in Appearance.apply(Appearance.from(v)) }
        .onChange(of: onboarded) { _, on in if on { ReminderScheduler.shared.reschedule() } }
        .onChange(of: phase, initial: true) { _, p in
            guard p == .active else { return }
            if onboarded { ReminderScheduler.shared.reschedule() }
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000) // after the first frame
                await PackSync.shared.autoCheck()
            }
        }
    }
}

/// «الرئيسية · محفوظاتي · المزيد» — the two treasures are reached from «الرئيسية».
struct MainTabView: View {
    @StateObject private var nav = AppNav()
    @ObservedObject private var router = NotificationRouter.shared
    @State private var probe: ReminderProbe?

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
        .overlay(alignment: .bottom) {
            if let probe { ReminderProbeView(probe: probe).padding(.bottom, 56) }
        }
        .onAppear { PackSync.shared.nav = nav }
        .onReceive(router.$pending) { open in
            guard let open else { return }
            nav.openName(open.nameId)
            DispatchQueue.main.async { router.pending = nil }
        }
        // a downloaded version waits while its pages are open
        .onChange(of: nav.homePath) { _, _ in
            Task { await PackSync.shared.activateReady(force: false) }
        }
        .task { probe = await ReminderProbe.runIfRequested() }
        .task { if Account.shared.isSignedIn { await SavedStore.shared.reload() } }
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
    /// A morning notification was tapped: «الرئيسية» → the name page.
    func openName(_ id: Int) {
        tab = 0
        homePath = [.names, .n(.name(id))]
    }
    /// Whether a page of the section is in the «الرئيسية» stack.
    func uses(_ s: PackSection) -> Bool { homePath.contains { $0.section == s } }
    /// Goes back out of the section's pages (before its content is replaced).
    func leave(_ s: PackSection) {
        if let i = homePath.firstIndex(where: { $0.section == s }) { homePath.removeSubrange(i...) }
    }
    /// Sibling pages (the previous / next category or time of «برنامج اليوم والليلة», of «ماذا يجلب هذا العمل؟») replace the current page.
    func replaceLastNames(_ route: NamesRoute) {
        if !homePath.isEmpty { homePath.removeLast() }
        homePath.append(.n(route))
    }
    func replaceLast(_ route: SunanRoute) {
        if !homePath.isEmpty { homePath.removeLast() }
        homePath.append(.s(route))
    }
}

/// Launch-argument routing for CI screenshots: `-route <name>` (see ci/routes.txt).
enum Route {
    static var arg: String { UserDefaults.standard.string(forKey: "route") ?? "home" }
    /// Launched by ci/screens.sh: no automatic content check (screens must not change under the camera).
    static var isCI: Bool { UserDefaults.standard.object(forKey: "route") != nil }
    static var initialTab: Int {
        switch arg {
        case "saved": return 1
        case "more", "moreupdate", "moreabout", "morebottom", "morefeedback": return 2
        default: return 0
        }
    }
    static var initialHomePath: [HomeDestination] {
        let firstSituation = NamesRepo.shared.door(1)?.situationIds.first ?? 1
        let feelSituation: [HomeDestination] = [.names, .n(.feel), .n(.door(1)), .n(.situation(firstSituation))]
        switch arg {
        case "names", "nod": return [.names]
        case "sunan", "sunandomains": return [.sunan]
        case "feel": return [.names, .n(.feel)]
        case "door": return [.names, .n(.feel), .n(.door(1))]
        case "situation": return feelSituation
        case "nameinsit": return [.names, .n(.feel), .n(.door(1)), .n(.situation(1)), .n(.nameInSituation(name: 99, situation: 1))]
        case "name20": return [.names, .n(.name(20))]
        case "name20v", "savesheet", "namevshare": return [.names, .n(.name(20, focus: 1))]
        case "name20w", "namewshare": return [.names, .n(.name(20, tab: .sunnah, focus: 1))]
        case "name20pray": return [.names, .n(.name(20, tab: .pray))]
        case "name20sunnah": return [.names, .n(.name(20, tab: .sunnah))]
        case "name1": return [.names, .n(.name(1))]
        case "allnames": return [.names, .n(.allNames())]
        case "namecat": return [.names, .n(.allNames()), .n(.nameCategory("أسماء الألوهية"))]
        case "namecat2": return [.names, .n(.allNames()), .n(.nameCategory("توابع الأسماء الحسنى"))]
        case "anfus": return [.names, .n(.feel), .n(.anfus())]
        case "anfusgroup":
            let slug = NamesRepo.shared.inner.first?.slug ?? ""
            return [.names, .n(.feel), .n(.anfus()), .n(.anfusGroup(slug))]
        case "ask": return [.names, .n(.ask())]
        // sunan section (ci/routes.txt `s…`)
        case "sask": return [.sunan, .s(.ask())]
        case "sall": return [.sunan, .s(.all)]
        case "sask2": return [.sunan, .s(.ask(question: "أواجه مشكلة كبيرة"))]
        case "sdomain": return [.sunan, .s(.domain(1))]
        case "sneed": return [.sunan, .s(.domain(1)), .s(.need(1))]
        case "sstate": return [.sunan, .s(.domain(1)), .s(.need(1)), .s(.state(1))]
        case "sitem", "sitemtext", "sitemmore", "ssavesheet", "sitemshare":
            return [.sunan, .s(.domain(1)), .s(.need(1)), .s(.state(1)), .s(.item(fp: "2c3521d318c6"))]
        case "sitemq", "sitemqtext":
            return [.sunan, .s(.domain(1)), .s(.need(1)), .s(.state(3)), .s(.item(fp: "b864df3937b5"))]
        case "sitemfp": return [.sunan, .s(.item(fp: "1c481e4cc3c2"))]
        case "sday": return [.sunan, .s(.day)]
        case "sdayperiod": return [.sunan, .s(.day), .s(.dayPeriod(1))]
        case "sdaytime": return [.sunan, .s(.day), .s(.dayPeriod(1)), .s(.dayTime(2))]
        case "sdeeds": return [.sunan, .s(.deeds)]
        case "sdeedkind": return [.sunan, .s(.deeds), .s(.deedKind("good"))]
        case "sdeedcat": return [.sunan, .s(.deeds), .s(.deedKind("good")), .s(.deedCategory("الأخلاق"))]
        case "sdeed": return [.sunan, .s(.deeds), .s(.deedKind("good")), .s(.deedCategory("الإحسان إلى الناس")), .s(.deed(1))]
        case "smacro": return [.sunan, .s(.macro)]
        case "smacrod": return [.sunan, .s(.macro), .s(.macroDomain("الرزق والمال"))]
        case "spairs": return [.sunan, .s(.pairs)]
        case "smethod": return [.sunan, .s(.method)]
        case "ssearch": return [.sunan, .s(.search(query: "رزق"))]
        default: return arg.hasPrefix("namesintro") || arg.hasPrefix("bismintro") ? [.names] : []  // a journey over the names home
        }
    }

    /// `sitemtext` / `sitemqtext`: the item page scrolled to the end of its full text, folds open; `sitemmore`: to «بمعناها»;
    /// `sunandomains`: the section home at «ماذا تحتاج الآن؟».
    private static var sunanScrollPending: String? = {
        switch arg {
        case "sitemtext", "sitemqtext": return "legend"
        case "sitemmore": return "more"
        case "sunandomains": return "domains"
        default: return nil
        }
    }()
    /// Consumed only by the page that has the anchor (pages lower in the stack may appear first).
    static func consumeSunanScroll(_ anchors: Set<String>) -> String? {
        guard let a = sunanScrollPending, anchors.contains(a) else { return nil }
        sunanScrollPending = nil
        return a
    }
    static var sunanOpenFolds: Bool { ["sitemtext", "sitemqtext"].contains(arg) }
    /// `moreupdate`: «المزيد» at «المحتوى», then «تحقّق من التحديث» pressed; `morebottom`: at the version line;
    /// `moreabout`: «عن المنصة» open.
    static var moreScroll: String? {
        switch arg {
        case "moreupdate": return "content"
        case "morebottom": return "version"
        default: return nil
        }
    }
    static var moreCheckNow: Bool { arg == "moreupdate" }
    static var moreOpenAbout: Bool { arg == "moreabout" }
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
