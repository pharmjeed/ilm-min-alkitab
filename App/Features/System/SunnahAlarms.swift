import AlarmKit
import SwiftUI

/// «المنبّه» (owner 2026-11-27): a real alarm — it rings and fills the screen, even on silent — for a sunnah at the
/// time the reader picks (e.g. «إذا دعوت في ساعة الجمعة» every Friday). iOS 26+ (AlarmKit). Added from the sunnah's
/// page («منبّه»), listed and removed in «المزيد». The system keeps the alarms; the app keeps what each one is.
struct SunnahAlarmRecord: Codable, Identifiable, Hashable {
    var id: UUID
    var fp: String
    var stateId: Int
    /// What the alarm shows: the sunnah (its cause, without the result).
    var title: String
    var hour: Int
    var minute: Int
    /// 1 = Sunday … 7 = Saturday (Calendar's numbering); empty = once.
    var weekdays: [Int]

    static let dayNames = ["الأحد", "الإثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت"]

    var timeText: String {
        let h12 = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d", h12, minute) + (hour < 12 ? " ص" : " م")
    }

    var daysText: String {
        if weekdays.isEmpty { return "مرة واحدة" }
        if weekdays.count == 7 { return "كل يوم" }
        return weekdays.sorted().map { Self.dayNames[$0 - 1] }.joined(separator: "، ")
    }
}

@available(iOS 26.0, *)
struct SunnahAlarmMeta: AlarmMetadata {
    var fp: String
}

@available(iOS 26.0, *)
@MainActor
enum SunnahAlarms {
    private static let key = "sunnah.alarms"

    static var records: [SunnahAlarmRecord] {
        get {
            guard let d = UserDefaults.standard.data(forKey: key),
                  let r = try? JSONDecoder().decode([SunnahAlarmRecord].self, from: d) else { return [] }
            return r
        }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: key) }
    }

    /// Asks once; false when the reader refused (then only «الإعدادات» can allow it).
    static func authorize() async -> Bool {
        let m = AlarmManager.shared
        switch m.authorizationState {
        case .authorized: return true
        case .denied: return false
        default: return (try? await m.requestAuthorization()) == .authorized
        }
    }

    static func add(_ r: SunnahAlarmRecord) async throws {
        let stop = AlarmButton(text: "إيقاف", textColor: .white, systemImageName: "stop.circle")
        let alert = AlarmPresentation.Alert(title: LocalizedStringResource("\(r.title)"), stopButton: stop)
        let attributes = AlarmAttributes<SunnahAlarmMeta>(presentation: AlarmPresentation(alert: alert),
                                                          metadata: SunnahAlarmMeta(fp: r.fp), tintColor: WidgetLook.gold)
        let days = r.weekdays.sorted().map { weekday($0) }
        let time = Alarm.Schedule.Relative.Time(hour: r.hour, minute: r.minute)
        let schedule = Alarm.Schedule.relative(.init(time: time, repeats: days.isEmpty ? .never : .weekly(days)))
        let config = AlarmManager.AlarmConfiguration<SunnahAlarmMeta>.alarm(schedule: schedule, attributes: attributes)
        _ = try await AlarmManager.shared.schedule(id: r.id, configuration: config)
        records = records + [r]
    }

    static func remove(_ id: UUID) {
        try? AlarmManager.shared.cancel(id: id)
        records = records.filter { $0.id != id }
    }

    /// Drops the records of alarms the system no longer has (a one-time alarm that already rang).
    static func prune() {
        guard let live = try? AlarmManager.shared.alarms else { return }
        let ids = Set(live.map(\.id))
        let kept = records.filter { ids.contains($0.id) }
        if kept.count != records.count { records = kept }
    }

    private static func weekday(_ n: Int) -> Locale.Weekday {
        [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday][max(0, min(6, n - 1))]
    }
}

/// «منبّه» on a sunnah's page (iOS 26+): opens the sheet that sets its alarm.
struct AlarmPill: View {
    let fp: String
    let stateId: Int
    let title: String
    @State private var show = false

    var body: some View {
        if #available(iOS 26.0, *) {
            Button { show = true } label: {
                ActionPill { Label { Text("منبّه") } icon: { Image(systemName: "alarm") } }
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $show) {
                SunnahAlarmSheet(fp: fp, stateId: stateId, title: title)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .onAppear {
                // CI screenshot of the sheet (ci/routes.txt `sitemalarm`)
                if Route.isCI, Route.arg == "sitemalarm", !AlarmCI.shown { AlarmCI.shown = true; show = true }
            }
        }
    }
}

enum AlarmCI { static var shown = false }

/// The time and the days, then «أضف المنبّه».
@available(iOS 26.0, *)
struct SunnahAlarmSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    let fp: String
    let stateId: Int
    let title: String
    @State private var time = SunnahAlarmSheet.nextHour()
    @State private var days: Set<Int> = []
    @State private var note: String?
    @State private var busy = false

    var body: some View {
        let t = Theme(scheme)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(title).font(AppFont.serif(22)).foregroundStyle(t.cream).lineSpacing(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel).labelsHidden()
                        .frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("الأيام").font(AppFont.sans(15, .medium)).foregroundStyle(t.gold)
                        FlowLayout(spacing: 8, lineSpacing: 8) {
                            ForEach(1...7, id: \.self) { d in
                                Button {
                                    if days.contains(d) { days.remove(d) } else { days.insert(d) }
                                } label: {
                                    ActionPill(on: days.contains(d)) { Text(SunnahAlarmRecord.dayNames[d - 1]) }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Text(days.isEmpty ? "بلا أيام: يرنّ مرة واحدة." : days.count == 7 ? "يرنّ كل يوم." : "يرنّ في الأيام المختارة كل أسبوع.")
                            .font(AppFont.sans(13)).foregroundStyle(t.muted)
                    }
                    Button { Task { await add() } } label: {
                        Label { Text("أضف المنبّه") } icon: { Image(systemName: "alarm") }.frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryPill())
                    .disabled(busy)
                    if let note {
                        Text(note).font(AppFont.sans(14)).foregroundStyle(t.muted).lineSpacing(5)
                    }
                }
                .padding(20)
            }
            .background(t.bg.ignoresSafeArea())
            .navigationTitle("منبّه السنّة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إغلاق") { dismiss() }.foregroundStyle(t.gold)
                }
            }
        }
    }

    private func add() async {
        busy = true
        defer { busy = false }
        guard await SunnahAlarms.authorize() else {
            note = "المنبّه غير مسموح للتطبيق. اسمح به من «الإعدادات» ثم «علم من الكتاب»."
            return
        }
        let c = Calendar.current.dateComponents([.hour, .minute], from: time)
        let r = SunnahAlarmRecord(id: UUID(), fp: fp, stateId: stateId, title: title, hour: c.hour ?? 6,
                                  minute: c.minute ?? 0, weekdays: days.sorted())
        do {
            try await SunnahAlarms.add(r)
            dismiss()
        } catch {
            note = "لم يُضف المنبّه، حاول مرة أخرى."
        }
    }

    private static func nextHour() -> Date {
        let cal = Calendar.current
        let h = (cal.component(.hour, from: Date()) + 1) % 24
        return cal.date(bySettingHour: h, minute: 0, second: 0, of: Date()) ?? Date()
    }
}
