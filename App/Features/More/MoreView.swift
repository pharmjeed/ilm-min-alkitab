import SwiftUI
import UIKit
import UserNotifications

/// «المزيد»: appearance, text size, the morning and evening reminders, feedback, the optional account (sign in / sign out / delete) and the version line.
struct MoreView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var phase
    @AppStorage("appearance") private var appearance = Appearance.dark.rawValue
    @AppStorage("reminder.enabled") private var reminderOn = true
    @AppStorage("reminder.hour") private var hour = 7
    @AppStorage("reminder.minute") private var minute = 0
    @AppStorage("evening.enabled") private var eveningOn = true
    @AppStorage("evening.hour") private var eveningHour = 21
    @AppStorage("evening.minute") private var eveningMinute = 0
    @AppStorage(WidgetShare.key) private var widgetCollection = ""
    @AppStorage(LiveToday.key) private var liveOn = true
    @ObservedObject private var sync = PackSync.shared
    @State private var auth: UNAuthorizationStatus?
    @State private var showAbout = Route.moreOpenAbout
    @State private var showFeedback = Route.arg == "morefeedback"
    @State private var ciDone = false
    @State private var signingIn = false
    @State private var confirmDelete = false
    @State private var showSearchCheck = false
    @State private var showWallpaper = Route.arg == "wallpaper"
    @State private var alarms: [SunnahAlarmRecord] = []

    static let sampleAyah = "﴿وَلِلَّهِ الْأَسْمَاءُ الْحُسْنَىٰ فَادْعُوهُ بِهَا﴾"

    var body: some View {
        let t = Theme(scheme)
        let _ = sync.contentVersion
        ScrollViewReader { proxy in
            List {
                appearanceSection(t)
                textSection(t)
                reminderSection(t)
                eveningSection(t)
                widgetSection(t)
                liveSection(t)
                wallpaperSection(t)
                if #available(iOS 26.0, *) { alarmsSection(t) }
                controlsSection(t)
                aboutSection(t)
                accountSection(t)
                Section {
                    Text(versionLine).font(AppFont.sans(13)).foregroundStyle(t.muted)
                        .frame(maxWidth: .infinity)
                        .id("version")
                        .onTapGesture { showSearchCheck = true }   // the iPhone search check
                }
                .listRowBackground(Color.clear)
            }
            .font(AppFont.sans(17))
            .foregroundStyle(t.cream)
            .scrollContentBackground(.hidden)
            .background(t.bg.ignoresSafeArea())
            .task {
                await refreshAuth()
                guard !ciDone else { return }
                ciDone = true
                if let anchor = Route.moreScroll {
                    try? await Task.sleep(nanoseconds: 600_000_000)
                    proxy.scrollTo(anchor, anchor: .top)
                }
                if Route.moreCheckNow { await sync.check(userInitiated: true) }
            }
        }
        .navigationTitle("المزيد")
        .navigationDestination(isPresented: $showAbout) { MarkdownPageView(page: .about) }
        .navigationDestination(isPresented: $showFeedback) { FeedbackView() }
        .navigationDestination(isPresented: $showSearchCheck) { SpotlightProbeView() }
        .navigationDestination(isPresented: $showWallpaper) { WallpaperPage() }
        .sheet(isPresented: $signingIn) { SaveSignInSheet(item: nil) }
        .confirmationDialog("حذف الحساب", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("احذف حسابي نهائيًا", role: .destructive) { Task { _ = await Account.shared.deleteAccount() } }
            Button("إلغاء", role: .cancel) {}
        } message: {
            Text("يُحذف حسابك وكل ما حفظته فيه، ولا يمكن استرجاعه.")
        }
        .onChange(of: phase) { _, p in if p == .active { Task { await refreshAuth() } } }
        .onAppear { loadAlarms() }
        .onChange(of: reminderOn) { _, on in Task { await reminderToggled(on) } }
        .onChange(of: hour) { _, _ in ReminderScheduler.shared.reschedule() }
        .onChange(of: minute) { _, _ in ReminderScheduler.shared.reschedule() }
        .onChange(of: eveningOn) { _, on in Task { await reminderToggled(on) } }
        .onChange(of: eveningHour) { _, _ in ReminderScheduler.shared.reschedule() }
        .onChange(of: eveningMinute) { _, _ in ReminderScheduler.shared.reschedule() }
        .onChange(of: widgetCollection) { _, _ in Task { await WidgetShare.sync() } }
        .onChange(of: liveOn) { _, _ in Task { await LiveToday.refresh(byUser: true) } }
    }

    // MARK: sections

    private func appearanceSection(_ t: Theme) -> some View {
        Section {
            Picker("المظهر", selection: $appearance) {
                ForEach(Appearance.allCases) { a in Text(a.label).tag(a.rawValue) }
            }
            .pickerStyle(.segmented)
        } header: {
            header("المظهر", t)
        } footer: {
            footer("«تلقائي» يتبع إعداد الآيفون.", t)
        }
        .listRowBackground(t.surface)
    }

    private func textSection(_ t: Theme) -> some View {
        Section {
            Picker("حجم النص", selection: Binding(get: { TextScale.shared.level }, set: { TextScale.shared.set($0) })) {
                ForEach(TextScale.Level.allCases) { l in Text(l.label).tag(l) }
            }
            .pickerStyle(.segmented)
            VStack(alignment: .leading, spacing: 6) {
                Text(Self.sampleAyah).font(AppFont.amiri(22)).foregroundStyle(t.gold).lineSpacing(6)
                Text("هكذا يظهر النص في صفحات التطبيق.").font(AppFont.sans(16)).foregroundStyle(t.cream.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        } header: {
            header("حجم النص", t)
        } footer: {
            footer("ويتبع أيضًا حجم الخط الذي تختاره في إعدادات الآيفون.", t)
        }
        .listRowBackground(t.surface)
    }

    private func reminderSection(_ t: Theme) -> some View {
        Section {
            Toggle(isOn: $reminderOn) {
                Text("تذكير الصباح").font(AppFont.sans(17)).foregroundStyle(t.cream)
            }
            .tint(t.gold)
            if reminderOn {
                DatePicker(selection: timeBinding, displayedComponents: .hourAndMinute) {
                    Text("وقت التذكير").font(AppFont.sans(17)).foregroundStyle(t.cream)
                }
                .tint(t.gold)
            }
            if reminderOn && auth == .denied {
                VStack(alignment: .leading, spacing: 8) {
                    Text("الإشعارات موقوفة لهذا التطبيق في إعدادات الآيفون، فلن يصلك التذكير حتى تسمح بها.")
                        .font(AppFont.sans(14)).foregroundStyle(t.neg)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("افتح إعدادات الآيفون") {
                        if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
                    }
                    .font(AppFont.sans(15, .medium)).foregroundStyle(t.gold)
                    .buttonStyle(.borderless)
                }
                .padding(.vertical, 4)
            }
        } header: {
            header("تذكير الصباح", t)
        } footer: {
            footer(reminderOn ? "يصلك كل صباح «اسم اليوم» ومعناه، ويفتح صفحته حين تضغط عليه."
                              : "التذكير موقوف، فلن تصلك إشعارات الصباح.", t)
        }
        .listRowBackground(t.surface)
    }

    // owner 2026-11-25: the «المحتوى» section (versions, last check, «تحقّق من التحديث») removed — the content still
    // updates by itself when the app opens (PackSync)

    private func aboutSection(_ t: Theme) -> some View {
        Section {
            // owner 2026-11-25: «عن المنصة» and «المنهجية» removed
            // owner 2026-11-25: sent from the app itself (FeedbackView), not through the website
            NavigationLink { FeedbackView() } label: { rowLabel(t, "envelope", "أرسل ملاحظة") }
        } header: {
            header("عن التطبيق", t)
        } footer: {
            footer("تصل ملاحظتك إلى صاحب المنصة مباشرة.", t)
        }
        .listRowBackground(t.surface)
    }

    private func accountSection(_ t: Theme) -> some View {
        let account = Account.shared
        return Section {
            if let s = account.session {
                VStack(alignment: .leading, spacing: 4) {
                    Text("مسجّل بحساب «\(account.providerName)»").font(AppFont.sans(17)).foregroundStyle(t.cream)
                    if let email = s.email, !email.isEmpty {
                        Text(email).font(AppFont.sans(14)).foregroundStyle(t.muted)
                            .environment(\.layoutDirection, .leftToRight)
                    }
                }
                Button { Task { await account.signOut() } } label: {
                    rowLabel(t, "rectangle.portrait.and.arrow.right", "تسجيل الخروج")
                }
                Button { confirmDelete = true } label: {
                    Label {
                        Text("حذف الحساب").font(AppFont.sans(17)).foregroundStyle(t.neg)
                    } icon: {
                        Image(systemName: "trash").foregroundStyle(t.neg)
                    }
                }
                .disabled(account.busy)
                if let e = account.errorText {
                    Text(e).font(AppFont.sans(14)).foregroundStyle(t.neg)
                }
            } else {
                Button { signingIn = true } label: {
                    rowLabel(t, "person.crop.circle", "سجّل الدخول بـ«آبل» أو «قوقل»")
                }
            }
        } header: {
            header("الحساب", t)
        } footer: {
            footer(account.isSignedIn
                   ? "ما تحفظه في «محفوظاتي» محفوظٌ في حسابك، وتجده على أي جهازٍ تدخل منه."
                   : "الحساب اختياري، ويُطلب عند الحفظ فقط.", t)
        }
        .listRowBackground(t.surface)
    }

    // MARK: pieces

    private func header(_ text: String, _ t: Theme) -> some View {
        Text(text).font(AppFont.sans(14, .medium)).foregroundStyle(t.gold)
    }

    private func footer(_ text: String, _ t: Theme) -> some View {
        Text(text).font(AppFont.sans(13)).foregroundStyle(t.muted).lineSpacing(4)
    }

    private func rowLabel(_ t: Theme, _ icon: String, _ title: String) -> some View {
        Label {
            Text(title).font(AppFont.sans(17)).foregroundStyle(t.cream)
        } icon: {
            Image(systemName: icon).foregroundStyle(t.gold)
        }
    }

    private var versionLine: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "علم من الكتاب · الإصدار \(v) (\(b))"
    }

    /// «تذكير المساء» (owner 2026-11-26): «سنّة اليوم» — the same sunnah as the home widget.
    private func eveningSection(_ t: Theme) -> some View {
        Section {
            Toggle(isOn: $eveningOn) {
                Text("تذكير المساء").font(AppFont.sans(17)).foregroundStyle(t.cream)
            }
            .tint(t.gold)
            if eveningOn {
                DatePicker(selection: eveningBinding, displayedComponents: .hourAndMinute) {
                    Text("وقت التذكير").font(AppFont.sans(17)).foregroundStyle(t.cream)
                }
                .tint(t.gold)
            }
        } header: {
            header("تذكير المساء", t)
        } footer: {
            footer(eveningOn ? "يصلك كل مساء «سنّة اليوم» من «برنامج اليوم والليلة» وثمرتها، ويفتحها حين تضغط عليه."
                             : "تذكير المساء موقوف.", t)
        }
        .listRowBackground(t.surface)
    }

    /// «أداة الشاشة الرئيسية» (owner 2026-11-26): «تلقائي» — the day's name and sunnah —, one of them always, or a
    /// collection of «محفوظاتي».
    private func widgetSection(_ t: Theme) -> some View {
        let cols = SavedStore.shared.collections.filter { !$0.items.isEmpty }
        let current = widgetValue(widgetCollection, cols, fallback: "")
        let signedIn = Account.shared.isSignedIn
        return Section {
            widgetRow("تلقائي: اسم اليوم وسنّة اليوم", current == "", t) { widgetCollection = "" }
            widgetRow("اسم اليوم دائمًا", current == WidgetShare.name, t) { widgetCollection = WidgetShare.name }
            widgetRow("سنّة اليوم دائمًا", current == WidgetShare.sunnah, t) { widgetCollection = WidgetShare.sunnah }
            ForEach(cols) { c in
                widgetRow("\(c.title) · \(c.items.count)", current == c.id, t) { widgetCollection = c.id }
            }
        } header: {
            header("أداة الشاشة الرئيسية", t)
        } footer: {
            footer(homeWidgetNote(current, signedIn: signedIn, hasCollections: !cols.isEmpty), t)
        }
        .listRowBackground(t.surface)
    }

    /// «خلفية الشاشة» (owner 2026-11-27): the day's name as a wallpaper picture (Wallpaper.swift).
    private func wallpaperSection(_ t: Theme) -> some View {
        Section {
            Button { showWallpaper = true } label: {
                HStack {
                    rowLabel(t, "photo", "خلفية اسم اليوم")
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.left").font(.footnote).foregroundStyle(t.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .id("wallpaper")
        } header: {
            header("خلفية الشاشة", t)
        } footer: {
            footer("صورة بحجم الشاشة فيها اسم اليوم وآية من مواضعه، تحفظها خلفيةً للجوال، أو تجعلها تتغيّر وحدها كل صباح.", t)
        }
        .listRowBackground(t.surface)
    }

    /// «منبّهات السنن» (owner 2026-11-27): the alarms added from the sunan pages (SunnahAlarms.swift), iOS 26+.
    @available(iOS 26.0, *)
    private func alarmsSection(_ t: Theme) -> some View {
        Section {
            ForEach(alarms) { a in
                VStack(alignment: .leading, spacing: 4) {
                    Text(a.title).font(AppFont.sans(16)).foregroundStyle(t.cream).lineLimit(2)
                    Text("\(a.timeText) · \(a.daysText)").font(AppFont.sans(13)).foregroundStyle(t.gold)
                }
                .swipeActions {
                    Button(role: .destructive) {
                        SunnahAlarms.remove(a.id)
                        loadAlarms()
                    } label: { Text("حذف") }
                }
            }
        } header: {
            header("منبّهات السنن", t)
        } footer: {
            footer(alarms.isEmpty
                   ? "أضف منبّهًا لأي سنّة من صفحتها بزر «منبّه»: يرنّ في الوقت والأيام التي تختارها، كساعة الجمعة."
                   : "لحذف منبّه اسحبه إلى اليسار. وتضيف غيره من صفحة أي سنّة بزر «منبّه».", t)
        }
        .listRowBackground(t.surface)
    }

    private func loadAlarms() {
        if #available(iOS 26.0, *) {
            SunnahAlarms.prune()
            alarms = SunnahAlarms.records
        }
    }

    /// «مركز التحكم» (owner 2026-11-27): how to add the two buttons (Widgets/IlmControls.swift).
    private func controlsSection(_ t: Theme) -> some View {
        Section {
            Text("اسحب من أعلى يمين الشاشة إلى الأسفل، ثم اضغط مطوّلًا على مكان فارغ، ثم «إضافة عنصر تحكم»، وابحث عن «علم من الكتاب» واختر «اسم اليوم» أو «سنّة اليوم».")
                .font(AppFont.sans(15)).foregroundStyle(t.cream).lineSpacing(5)
        } header: {
            header("مركز التحكم", t)
        } footer: {
            footer("وتستطيع أن تضع الزر نفسه مكان المصباح أو الكاميرا أسفل شاشة القفل: اضغط مطوّلًا على شاشة القفل، ثم «تخصيص».", t)
        }
        .listRowBackground(t.surface)
    }

    /// «العرض الكبير على شاشة القفل» (owner 2026-11-26): the day's sunnah on a card as wide as the screen (a Live
    /// Activity), until «تمّت» or the system's limit.
    private func liveSection(_ t: Theme) -> some View {
        Section {
            Toggle(isOn: $liveOn) {
                Text("العرض الكبير على شاشة القفل").font(AppFont.sans(17)).foregroundStyle(t.cream)
            }
            .tint(t.gold)
        } header: {
            header("العرض الكبير", t)
        } footer: {
            footer(liveOn ? "تظهر «سنّة اليوم» على شاشة القفل ببطاقة بعرض الشاشة حين تفتح التطبيق أول مرة في اليوم، وتبقى حتى تضغط «تمّت» أو نحو 8 ساعات (حدّ الآيفون)."
                          : "بطاقة بعرض الشاشة على شاشة القفل فيها «سنّة اليوم» وثمرتها.", t)
        }
        .listRowBackground(t.surface)
    }

    private func homeWidgetNote(_ current: String, signedIn: Bool, hasCollections: Bool) -> String {
        if current == WidgetShare.name { return "اسم اليوم كل يوم، مع آية من مواضعه تتبدّل كل ساعة." }
        if current == WidgetShare.sunnah { return "سنّة اليوم كل يوم من «برنامج اليوم والليلة»، مع ثمرتها." }
        if !current.isEmpty { return "تمر عناصر المجموعة في الأداة واحدًا كل ساعة، وزر «التالي» فيها ينقلك إلى ما بعده." }
        if !signedIn { return "لتظهر في الأداة مجموعتك: سجّل الدخول، ثم أنشئ في «محفوظاتي» مجموعة من الأسماء والسنن والمواضع." }
        if !hasCollections { return "أنشئ في «محفوظاتي» مجموعة من الأسماء والسنن والمواضع، ثم اخترها هنا لتظهر في الأداة." }
        return "تلقائي: يومًا اسم اليوم مع آية من مواضعه تتبدّل كل ساعة، ويومًا سنّة اليوم."
    }

    /// The stored choice, or `fallback` when its collection is gone.
    private func widgetValue(_ v: String, _ cols: [SavedCollection], fallback: String) -> String {
        if ["", WidgetShare.name, WidgetShare.sunnah].contains(v) { return v }
        return cols.contains { $0.id == v } ? v : fallback
    }

    private func widgetRow(_ title: String, _ on: Bool, _ t: Theme, _ pick: @escaping () -> Void) -> some View {
        Button(action: pick) {
            HStack {
                Text(title).font(AppFont.sans(17)).foregroundStyle(t.cream).multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if on { Image(systemName: "checkmark").foregroundStyle(t.gold) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var eveningBinding: Binding<Date> {
        Binding(get: {
            Calendar.current.date(bySettingHour: eveningHour, minute: eveningMinute, second: 0, of: Date()) ?? Date()
        }, set: { d in
            let c = Calendar.current.dateComponents([.hour, .minute], from: d)
            eveningHour = c.hour ?? 21
            eveningMinute = c.minute ?? 0
        })
    }

    private var timeBinding: Binding<Date> {
        Binding(get: {
            Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        }, set: { d in
            let c = Calendar.current.dateComponents([.hour, .minute], from: d)
            hour = c.hour ?? 7
            minute = c.minute ?? 0
        })
    }

    @MainActor
    private func refreshAuth() async {
        auth = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Turning the reminder on asks for permission if it was never asked; off removes the pending notifications.
    @MainActor
    private func reminderToggled(_ on: Bool) async {
        if on && auth == .notDetermined {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuth()
        }
        ReminderScheduler.shared.reschedule()
    }
}
