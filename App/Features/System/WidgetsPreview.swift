import SwiftUI
import WidgetKit

/// CI only (`-route widgets` / `widgets2`): the widgets drawn inside the app at their real sizes — a day of the name,
/// then a day of the sunnah — so their screenshots can be checked before an upload.
struct WidgetsPreview: View {
    let sunnah: Bool

    var body: some View {
        let c = Today.Content.app
        let now = Date()
        let e = TodayEntry(date: now, name: c.name(now), sunnah: c.sunnah(now), showsSunnah: sunnah)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(sunnah ? "أداة الشاشة الرئيسية — يوم السنّة" : "أداة الشاشة الرئيسية — يوم الاسم")
                    .font(WidgetLook.sans(13, .medium)).foregroundStyle(.white.opacity(0.8))
                if !sunnah {
                    // the lock screen box at its size (dashed edge), for today's name and for a medium and the longest name
                    Text("شاشة القفل").font(WidgetLook.sans(12, .medium)).foregroundStyle(.white.opacity(0.8))
                    let samples = lockSamples(c)
                    HStack(spacing: 12) {
                        lock(e)
                        if let s = samples.first { lock(s) }
                    }
                    HStack(spacing: 12) {
                        if samples.count > 1 { lock(samples[1]) }
                        TodayWidgetView(entry: e, family: .accessoryInline)
                            .font(WidgetLook.sans(13)).foregroundStyle(.white)
                            .lineLimit(1)
                    }
                }
                home(e, .systemSmall, 158, 158)
                home(e, .systemMedium, 338, 158)
                home(e, .systemLarge, 338, 354)
            }
            .padding(20)
        }
        .background(Color(red: 0.16, green: 0.2, blue: 0.24).ignoresSafeArea())
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func lock(_ e: TodayEntry) -> some View {
        TodayWidgetView(entry: e, family: .accessoryRectangular)
            .foregroundStyle(.white)
            .frame(width: 160, height: 72)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
    }

    /// A name of about twenty letters and the longest name, to see the lock box's smaller layouts.
    private func lockSamples(_ c: Today.Content) -> [TodayEntry] {
        guard let all = c.names?.names, !all.isEmpty else { return [] }
        let medium = all.min { abs($0.name.count - 22) < abs($1.name.count - 22) }!
        let longest = all.max { $0.name.count < $1.name.count }!
        return [medium, longest].map {
            TodayEntry(date: Date(), name: Today.Name(id: $0.id, name: $0.name, excerpt: $0.excerpt), sunnah: nil, showsSunnah: false)
        }
    }

    private func home(_ e: TodayEntry, _ f: WidgetFamily, _ w: CGFloat, _ h: CGFloat) -> some View {
        TodayWidgetView(entry: e, family: f)
            .padding(16)
            .frame(width: w, height: h)
            .background(WidgetLook.night)
            .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}
