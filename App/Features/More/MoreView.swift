import SwiftUI
import UIKit
import UserNotifications

/// «المزيد»: appearance, text size, the morning reminder, content updates, about / methodology (from the names pack),
/// feedback, the account placeholder and the version line.
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

    static let sampleAyah = "﴿وَلِلَّهِ الْأَسْمَاءُ الْحُسْنَىٰ فَادْعُوهُ بِهَا﴾"

    var body: some View {
        let t = Theme(scheme)
        let _ = sync.contentVersion
        ScrollViewReader { proxy in
            List {
                appearanceSection(t)
                textSection(t)
                reminderSection(t)
                contentSection(t)
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

    private func contentSection(_ t: Theme) -> some View {
        Section {
            contentRow(t, .names, count: Arabic.count(NamesRepo.shared.names.count, Arabic.names),
                       date: NamesRepo.shared.index?.generatedAt)
                .id("content")
            contentRow(t, .sunan, count: SunanText.count(SunanRepo.shared.index?.stats.items ?? 0, SunanText.sunan),
                       date: SunanRepo.shared.index?.generatedAt)
            LabeledContent {
                Text(sync.lastCheck.map { ArabicDate.relative($0) } ?? "لم يُتحقَّق بعد")
                    .font(AppFont.sans(15)).foregroundStyle(t.muted)
            } label: {
                Text("آخر تحقّق").font(AppFont.sans(17)).foregroundStyle(t.cream)
            }
            Button {
                Task { await sync.check(userInitiated: true) }
            } label: {
                HStack(spacing: 10) {
                    if sync.busy { ProgressView().tint(t.gold) }
                    Text(SyncText.progress(sync.phase) ?? "تحقّق من التحديث")
                        .font(AppFont.sans(17, .medium)).foregroundStyle(sync.busy ? t.muted : t.gold)
                }
            }
            .disabled(sync.busy)
            switch sync.phase {
            case .done(let m):
                Label { Text(m).font(AppFont.sans(15)).foregroundStyle(t.result) } icon: {
                    Image(systemName: "checkmark.circle").foregroundStyle(t.result)
                }
            case .failed(let m):
                Label { Text(m).font(AppFont.sans(15)).foregroundStyle(t.neg) } icon: {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(t.neg)
                }
            default:
                EmptyView()
            }
        } header: {
            header("المحتوى", t)
        } footer: {
            footer("المحتوى كله يعمل دون إنترنت، ويُنزَّل الجديد من المنصة تلقائيًا عند فتح التطبيق.", t)
        }
        .listRowBackground(t.surface)
    }

    private func contentRow(_ t: Theme, _ s: PackSection, count: String, date: String?) -> some View {
        let downloaded = PackStore.isDownloaded(s)
        return VStack(alignment: .leading, spacing: 4) {
            Text(SyncText.title(s)).font(AppFont.sans(17, .medium)).foregroundStyle(t.cream)
            Text("\(count) · \(versionWords(date))").font(AppFont.sans(14)).foregroundStyle(t.muted)
            Text(downloaded ? "محدّثة من المنصة" : "النسخة المضمّنة في التطبيق")
                .font(AppFont.sans(13)).foregroundStyle(downloaded ? t.result : t.muted)
        }
        .padding(.vertical, 2)
    }

    private func aboutSection(_ t: Theme) -> some View {
        Section {
            NavigationLink { MarkdownPageView(page: .about) } label: { rowLabel(t, "info.circle", "عن المنصة") }
            NavigationLink { MarkdownPageView(page: .methodology) } label: { rowLabel(t, "book.closed", "المنهجية") }
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
        Section {
            rowLabel(t, "person.crop.circle", "الحساب — قريبًا")
        } header: {
            header("الحساب", t)
        } footer: {
            footer("الحساب اختياري، ويُطلب عند الحفظ فقط.", t)
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

    private func versionWords(_ iso: String?) -> String {
        ArabicDate.parseISO(iso).map { "نسخة \(ArabicDate.day($0))" } ?? "نسخة غير مؤرّخة"
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
