import SwiftUI
import WidgetKit

/// CI only: the widgets drawn inside the app at their real sizes, so their screenshots can be checked before an upload.
/// `widgets`: a day of the name (and the lock screen) · `widgets2`: a day of the sunnah · `widgets3` / `widgets4`: the
/// name with an ayah of about 120 / 260 letters · `widgets5`: a collection of «محفوظاتي».
struct WidgetsPreview: View {
    let route: String

    var body: some View {
        let c = Today.Content.app
        let now = Date()
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                switch route {
                case "widgets2": sunnahDay(c, now)
                case "widgets3": ayahSample(c, now, 120)
                case "widgets4": ayahSample(c, now, 260)
                case "widgets5": collection(c, now)
                default: nameDay(c, now)
                }
            }
            .padding(20)
        }
        .background(Color(red: 0.16, green: 0.2, blue: 0.24).ignoresSafeArea())
        .environment(\.layoutDirection, .rightToLeft)
    }

    // MARK: the screens

    @ViewBuilder private func nameDay(_ c: Today.Content, _ now: Date) -> some View {
        let e = nameEntry(c.name(now), now)
        title("أداة الشاشة الرئيسية — يوم الاسم (الموضع يتبدّل كل ساعة)")
        title("شاشة القفل")
        let samples = lockSamples(c, now)
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
        home(e, .systemSmall, 158, 158)
        home(e, .systemMedium, 338, 158)
        home(e, .systemLarge, 338, 354)
    }

    @ViewBuilder private func sunnahDay(_ c: Today.Content, _ now: Date) -> some View {
        let s = c.sunnah(now).map(TodayEntry.Slide.sunnah)
        let e = TodayEntry(date: now, header: "سنّة اليوم", slide: s, action: .toName, lockHeader: "سنّة اليوم", lockSlide: s)
        title("أداة الشاشة الرئيسية — يوم السنّة، وشاشة القفل")
        lock(e)
        home(e, .systemSmall, 158, 158)
        home(e, .systemMedium, 338, 158)
        home(e, .systemLarge, 338, 354)
    }

    @ViewBuilder private func ayahSample(_ c: Today.Content, _ now: Date, _ length: Int) -> some View {
        let e = sample(c, now, length) ?? nameEntry(c.name(now), now)
        title("يوم الاسم — آية من نحو \(length) حرفًا")
        home(e, .systemSmall, 158, 158)
        home(e, .systemMedium, 338, 158)
        home(e, .systemLarge, 338, 354)
    }

    /// A collection as the widget receives it: a name (its positions one after another), a sunnah, a situation.
    @ViewBuilder private func collection(_ c: Today.Content, _ now: Date) -> some View {
        let col = "مجموعتي: أذكار الصباح"
        let name = c.name(id: 20).map { TodayEntry.Slide.name($0, Today.verse(of: 20, slot: 1)) }
        let sunnah = c.sunnah(now).map(TodayEntry.Slide.sunnah)
        let situation = NamesRepo.shared.situation(1).map {
            TodayEntry.Slide.text(title: $0.situation.isEmpty ? $0.label : $0.situation,
                                  sub: NamesRepo.shared.door($0.doorId)?.label, link: nil)
        }
        let es = [name, sunnah, situation].map {
            TodayEntry(date: now, header: col, slide: $0, action: .next, lockHeader: col, lockSlide: $0)
        }
        title("أداة الشاشة الرئيسية — مجموعة من «محفوظاتي»")
        HStack(spacing: 12) {
            lock(es[1])
            lock(es[2])
        }
        HStack(alignment: .top, spacing: 14) {
            home(es[1], .systemSmall, 158, 158)
            home(es[2], .systemSmall, 158, 158)
        }
        home(es[0], .systemMedium, 338, 158)
        home(es[1], .systemMedium, 338, 158)
    }

    // MARK: pieces

    private func nameEntry(_ n: Today.Name?, _ now: Date, verse: Today.Verse? = nil) -> TodayEntry {
        let hour = Today.hourNumber(now)
        let s = n.map { TodayEntry.Slide.name($0, verse ?? Today.verse(of: $0.id, slot: hour)) }
        let lock = n.map { TodayEntry.Slide.name($0, Today.shortVerse(of: $0.id, slot: hour) ?? verse ?? Today.verse(of: $0.id, slot: hour)) }
        return TodayEntry(date: now, header: "اسم اليوم", slide: s, action: .toSunnah, lockHeader: "اسم اليوم", lockSlide: lock)
    }

    private func title(_ s: String) -> some View {
        Text(s).font(WidgetLook.sans(13, .medium)).foregroundStyle(.white.opacity(0.8))
    }

    private func lock(_ e: TodayEntry) -> some View {
        TodayWidgetView(entry: e, family: .accessoryRectangular)
            .foregroundStyle(.white)
            .frame(width: 160, height: 72)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
    }

    /// The name whose position has about `length` letters, with that position.
    private func sample(_ c: Today.Content, _ now: Date, _ length: Int) -> TodayEntry? {
        guard let all = c.names?.names else { return nil }
        var best: (id: Int, v: Today.Verse)?
        for n in all {
            for v in Today.verses(of: n.id) where best == nil || abs(v.text.count - length) < abs(best!.v.text.count - length) {
                best = (n.id, v)
            }
        }
        guard let b = best, let n = c.name(id: b.id) else { return nil }
        return nameEntry(n, now, verse: b.v)
    }

    /// A name with a short position (its ayah on the lock screen) and the longest name, to see the lock box's layouts.
    private func lockSamples(_ c: Today.Content, _ now: Date) -> [TodayEntry] {
        guard let all = c.names?.names, !all.isEmpty else { return [] }
        let short = all.first { $0.id > 1 && Today.shortVerse(of: $0.id, slot: 0, maxLetters: 40) != nil } ?? all[0]
        let longest = all.max { $0.name.count < $1.name.count }!
        return [short, longest].map { nameEntry(Today.Name(id: $0.id, name: $0.name, excerpt: $0.excerpt), now) }
    }

    private func home(_ e: TodayEntry, _ f: WidgetFamily, _ w: CGFloat, _ h: CGFloat) -> some View {
        TodayWidgetView(entry: e, family: f)
            .padding(16)
            .frame(width: w, height: h)
            .background(WidgetLook.night)
            .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}
