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
                HStack(alignment: .top, spacing: 14) {
                    home(e, .systemSmall, 158, 158)
                    if !sunnah {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("شاشة القفل").font(WidgetLook.sans(12, .medium)).foregroundStyle(.white.opacity(0.8))
                            TodayWidgetView(entry: e, family: .accessoryRectangular)
                                .foregroundStyle(.white)
                                .frame(width: 160, height: 72)
                            TodayWidgetView(entry: e, family: .accessoryInline)
                                .font(WidgetLook.sans(13)).foregroundStyle(.white)
                                .lineLimit(1)
                        }
                    }
                }
                home(e, .systemMedium, 338, 158)
                home(e, .systemLarge, 338, 354)
            }
            .padding(20)
        }
        .background(Color(red: 0.16, green: 0.2, blue: 0.24).ignoresSafeArea())
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func home(_ e: TodayEntry, _ f: WidgetFamily, _ w: CGFloat, _ h: CGFloat) -> some View {
        TodayWidgetView(entry: e, family: f)
            .padding(16)
            .frame(width: w, height: h)
            .background(WidgetLook.night)
            .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}
