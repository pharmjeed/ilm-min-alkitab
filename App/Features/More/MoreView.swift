import SwiftUI
import UIKit
import UserNotifications

/// «المزيد»: appearance, text size, the morning reminder, feedback, the optional account (sign in / sign out / delete) and the version line.
struct MoreView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var phase
    @AppStorage("appearance") private var appearance = Appearance.dark.rawValue
    @AppStorage("reminder.enabled") private var reminderOn = true
    @AppStorage("reminder.hour") private var hour = 7
    @AppStorage("reminder.minute") private var minute = 0
    @ObservedObject private var sync = PackSync.shared
    @State private var auth: UNAuthorizationStatus?
    @State private var showAbout = Route.moreOpenAbout
    @State private var ciDone = false
    @State private var signingIn = false
    @State private var confirmDelete = false

    static let sampleAyah = "﴿وَلِلَّهِ الْأَسْمَاءُ الْحُسْنَىٰ فَادْعُوهُ بِهَا﴾"

    var body: some View {
        let t = Theme(scheme)
        let _ = sync.contentVersion
        ScrollViewReader { proxy in
            List {
                appearanceSection(t)
                textSection(t)
                reminderSection(t)
                aboutSection(t)
                accountSection(t)
                Section {
                    Text(versionLine).font(AppFont.sans(13)).foregroundStyle(t.muted)
                        .frame(maxWidth: .infinity)
                        .id("version")
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
        .sheet(isPresented: $signingIn) { SaveSignInSheet(item: nil) }
        .confirmationDialog("حذف الحساب", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("احذف حسابي نهائيًا", role: .destructive) { Task { _ = await Account.shared.deleteAccount() } }
            Button("إلغاء", role: .cancel) {}
        } message: {
            Text("يُحذف حسابك وكل ما حفظته فيه، ولا يمكن استرجاعه.")
        }
        .onChange(of: phase) { _, p in if p == .active { Task { await refreshAuth() } } }
        .onChange(of: reminderOn) { _, on in Task { await reminderToggled(on) } }
        .onChange(of: hour) { _, _ in ReminderScheduler.shared.reschedule() }
        .onChange(of: minute) { _, _ in ReminderScheduler.shared.reschedule() }
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
            Link(destination: Site.url("/suggest")) {
                HStack {
                    rowLabel(t, "envelope", "أرسل ملاحظة")
                    Spacer()
                    Image(systemName: "arrow.up.forward").font(.system(size: 13, weight: .medium)).foregroundStyle(t.muted)
                }
            }
        } header: {
            header("عن التطبيق", t)
        } footer: {
            footer("تُفتح صفحة «اقتراح أو إضافة» في موقع المنصة، وتصل ملاحظتك إلى صاحبها.", t)
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
