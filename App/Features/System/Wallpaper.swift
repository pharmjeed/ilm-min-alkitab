import AppIntents
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// «خلفية الشاشة» (owner 2026-11-27): the day's name with one of its ayat — whole and verbatim — drawn at an iPhone's
/// screen size, to keep as the wallpaper. Its upper part stays empty for the lock screen's date and clock.
/// `NameWallpaperIntent` hands the same picture to the Shortcuts app, so an automation can set it every morning.
struct WallpaperView: View {
    let name: Today.Name
    let verse: Today.Verse?
    static let size = CGSize(width: 393, height: 852)

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 300)   // the lock screen's date and clock
            Text("اسم اليوم")
                .font(WidgetLook.sans(17, .medium)).foregroundStyle(WidgetLook.gold.opacity(0.85))
            Text(name.name)
                .font(WidgetLook.serif(54)).foregroundStyle(WidgetLook.gold)
                .lineLimit(2).minimumScaleFactor(0.5)
                .padding(.top, 4)
            if let v = verse {
                Text(ayah(v)).lineSpacing(6).padding(.top, 20)
            } else {
                Text(NotificationText.body(name.excerpt, max: 180))
                    .font(WidgetLook.sans(18)).foregroundStyle(WidgetLook.cream.opacity(0.9)).lineSpacing(6)
                    .padding(.top, 20)
            }
            Spacer(minLength: 0)
            Text("علم من الكتاب")
                .font(WidgetLook.sans(13, .medium)).foregroundStyle(WidgetLook.gold.opacity(0.55))
                .padding(.bottom, 128)   // above the flashlight and the camera
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 34)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(WidgetLook.night)
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func ayah(_ v: Today.Verse) -> AttributedString {
        var a = AttributedString("﴿\(v.text)﴾")
        a.font = WidgetLook.amiri(21)
        a.foregroundColor = WidgetLook.cream
        var r = AttributedString(" \(v.ref.nonBreaking)")
        r.font = WidgetLook.sans(13)
        r.foregroundColor = WidgetLook.cream.opacity(0.6)
        return a + r
    }
}

@MainActor
enum Wallpaper {
    /// Ayat longer than this would crowd the picture: the name then shows its meaning instead (an ayah is never cut).
    static let maxLetters = 170

    /// The day's name, and one of its ayat short enough to stay whole — a different one each day.
    static func content(_ now: Date = Date()) -> (name: Today.Name, verse: Today.Verse?)? {
        guard let n = Today.Content.app.name(now) else { return nil }
        let fit = Today.verses(of: n.id).filter { $0.text.count <= maxLetters }
        let day = Today.dayNumber(now)
        return (n, fit.isEmpty ? nil : fit[((day % fit.count) + fit.count) % fit.count])
    }

    /// The picture at 3× — 1179 × 2556 pixels, an iPhone's screen.
    static func image(_ now: Date = Date()) -> UIImage? {
        guard let c = content(now) else { return nil }
        let r = ImageRenderer(content: WallpaperView(name: c.name, verse: c.verse))
        r.scale = 3
        r.proposedSize = ProposedViewSize(WallpaperView.size)
        return r.uiImage
    }
}

/// The Shortcuts action «خلفية اسم اليوم»: the picture as a file, for «تعيين الخلفية» in a morning automation.
struct NameWallpaperIntent: AppIntent {
    static var title: LocalizedStringResource = "خلفية اسم اليوم"
    static var description = IntentDescription("صورة بحجم الشاشة فيها اسم اليوم وآية من مواضعه، لتجعلها خلفية الجوال كل صباح.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        guard let data = Wallpaper.image()?.pngData() else { throw WallpaperNotReady() }
        return .result(value: IntentFile(data: data, filename: "wallpaper.png", type: .png))
    }
}

struct WallpaperNotReady: Error, CustomLocalizedStringResourceConvertible {
    var localizedStringResource: LocalizedStringResource { "افتح علم من الكتاب مرة ليجهز المحتوى." }
}

/// «المزيد» › «خلفية الشاشة»: the picture, «احفظها في الصور», and how to set it — once, or every morning by itself.
struct WallpaperPage: View {
    @Environment(\.colorScheme) private var scheme
    @State private var image: UIImage?

    var body: some View {
        let t = Theme(scheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let image {
                    Image(uiImage: image).resizable().scaledToFit()
                        .frame(maxWidth: 230)
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                        .overlay(RoundedRectangle(cornerRadius: 26).stroke(t.line, lineWidth: 1))
                        .frame(maxWidth: .infinity)
                    ShareLink(item: Image(uiImage: image),
                              preview: SharePreview("خلفية اسم اليوم", image: Image(uiImage: image))) {
                        Label { Text("احفظها في الصور") } icon: { Image(systemName: "square.and.arrow.down") }
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryPill())
                } else {
                    ProgressView().frame(maxWidth: .infinity).frame(height: 300)
                }
                steps(t, "لتجعلها خلفيتك", [
                    "اضغط «احفظها في الصور»، ثم «حفظ الصورة».",
                    "افتح «الصور»، واختر الصورة، ثم زر المشاركة، ثم «استخدام كخلفية».",
                ])
                steps(t, "لتتغيّر وحدها كل صباح", [
                    "افتح تطبيق «الاختصارات»، ثم «الأتمتة»، ثم «+»، واختر «وقت من اليوم» وحدّد الوقت و«تشغيل فورًا».",
                    "أضف إجراء «خلفية اسم اليوم» من «علم من الكتاب».",
                    "أضف بعده إجراء تعيين صورة الخلفية (ابحث عن «الخلفية»)، واختر شاشة القفل.",
                ])
            }
            .padding(20)
        }
        .background(t.bg.ignoresSafeArea())
        .navigationTitle("خلفية الشاشة")
        .navigationBarTitleDisplayMode(.inline)
        .task { image = Wallpaper.image() }
    }

    private func steps(_ t: Theme, _ title: String, _ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(AppFont.sans(16, .bold)).foregroundStyle(t.gold)
            ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(i + 1).").font(AppFont.sans(15, .medium)).foregroundStyle(t.gold)
                    Text(line).font(AppFont.sans(15)).foregroundStyle(t.cream).lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface, in: RoundedRectangle(cornerRadius: 14))
    }
}
