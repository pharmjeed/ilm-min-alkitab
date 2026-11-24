import SwiftUI

// «برنامج اليوم والليلة» (/sunan/day → main category → /sunan/day/<time>) and «ماذا يجلب هذا العمل؟» (/sunan/deeds, /sunan/deeds/<deed>).

/// /sunan/day — the three main categories only; their sub-categories and sunan open on the next pages
/// (owner 2026-11-24: «لا تسرد السنن في هذه الصفحة … تصنيف أساسي، تصنيف فرعي، ثم السنن»).
struct SunanDayView: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let t = Theme(scheme)
        SunanLoader(key: "day", load: { try await SunanStore.shared.day() }) { day in
            SunanDayContent(day: day)
        }
        .sunanScreen(SunanText.dayTitle, t)
    }
}

private extension SunanDayPeriod {
    var itemsCount: Int { times.reduce(0) { $0 + $1.items.count } }
    /// «15 تصنيفًا · 452 سنّة»
    var countLine: String {
        "\(SunanText.count(times.count, SunanText.categories)) · \(SunanText.count(itemsCount, SunanText.sunan))"
    }
}

private struct SunanDayContent: View {
    @Environment(\.colorScheme) private var scheme
    let day: SunanDayFile

    var body: some View {
        let t = Theme(scheme)
        let total = day.periods.reduce(0) { $0 + $1.itemsCount }
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                CrumbsView(trail: [.sunanHome], current: SunanText.dayTitle)
                VStack(alignment: .leading, spacing: 0) {
                    Text(SunanText.dayTitle).font(AppFont.serif(30)).foregroundStyle(t.cream).lineSpacing(4)
                    Text(SunanText.dayLead).font(AppFont.sans(16)).foregroundStyle(t.cream.opacity(0.9)).lineSpacing(8)
                        .padding(.top, 12)
                    dayLegend(t, prefix: "\(SunanText.count(total, SunanText.sunan)) — ", size: 14).padding(.top, 8)
                }
                .multilineTextAlignment(.leading)
                .sunanHeader(t, gold: true)

                SunanHeading(text: "اختر ما يناسبك", size: 24).padding(.top, 32)
                VStack(spacing: 12) {
                    ForEach(day.periods) { p in
                        SunanLink(.dayPeriod(p.id)) { DayPeriodCard(period: p) }
                    }
                }
                .padding(.top, 16)
            }
            .padding(16).padding(.bottom, 24)
        }
    }
}

/// One main category: its ordinal, name, the first sub-categories, and the counts.
private struct DayPeriodCard: View {
    @Environment(\.colorScheme) private var scheme
    let period: SunanDayPeriod
    var body: some View {
        let t = Theme(scheme)
        let parts = SunanText.periodParts(period.title)
        let names = period.times.prefix(4).map(\.title).joined(separator: " · ") + (period.times.count > 4 ? " …" : "")
        VStack(alignment: .leading, spacing: 8) {
            if let o = parts.ordinal { Text(o).font(AppFont.sans(14)).foregroundStyle(t.gold) }
            Text(parts.name).font(AppFont.serif(26)).foregroundStyle(t.cream)
            Text(names).font(AppFont.sans(14)).foregroundStyle(t.muted).lineSpacing(6).lineLimit(2)
            Rectangle().fill(t.line).frame(height: 1).padding(.top, 4)
            HStack {
                Text(period.countLine)
                Spacer(minLength: 8)
                Text("افتح ←")
            }
            .font(AppFont.sans(14)).foregroundStyle(t.gold)
        }
        .multilineTextAlignment(.leading)
        .sunanRow(t, border: t.gold.opacity(0.45), h: 20, v: 20, radius: 16)
    }
}

/// «بالذهبي: ماذا تفعل · بالأخضر: ثمرته».
private func dayLegend(_ t: Theme, prefix: String = "", size: CGFloat) -> some View {
    var a = AttributedString("بالذهبي: ماذا تفعل")
    a.foregroundColor = t.gold
    var b = AttributedString("بالأخضر: ثمرته")
    b.foregroundColor = t.result
    return Text(AttributedString(prefix) + a + AttributedString(" · ") + b)
        .font(AppFont.sans(size)).foregroundStyle(t.muted)
        .frame(maxWidth: .infinity, alignment: .leading)
}

/// A main category of the programme: its sub-categories (times / situations) with their counts — no sunan here.
struct SunanDayPeriodView: View {
    @Environment(\.colorScheme) private var scheme
    let periodId: Int
    var body: some View {
        let t = Theme(scheme)
        SunanLoader(key: "day", load: { try await SunanStore.shared.day() }) { day in
            SunanDayPeriodContent(day: day, periodId: periodId)
        }
        .sunanScreen(SunanText.dayTitle, t)
    }
}

private struct SunanDayPeriodContent: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var nav: AppNav
    let day: SunanDayFile
    let periodId: Int

    var body: some View {
        let t = Theme(scheme)
        let k = day.periods.firstIndex { $0.id == periodId }
        ScrollView {
            if let k {
                let period = day.periods[k]
                let parts = SunanText.periodParts(period.title)
                let prev = k > 0 ? day.periods[k - 1] : nil
                let next = k + 1 < day.periods.count ? day.periods[k + 1] : nil
                VStack(alignment: .leading, spacing: 0) {
                    CrumbsView(trail: [.sunanHome, Crumb(SunanText.dayTitle, .day)], current: parts.name)
                        .padding(.bottom, 16)
                    VStack(alignment: .leading, spacing: 4) {
                        if let o = parts.ordinal { Text(o).font(AppFont.sans(14)).foregroundStyle(t.gold) }
                        Text(parts.name).font(AppFont.serif(30)).foregroundStyle(t.cream).lineSpacing(4)
                        Text("\(period.countLine) — اختر ما يناسب وقتك أو موقفك:")
                            .font(AppFont.sans(16)).foregroundStyle(t.cream.opacity(0.9)).lineSpacing(6)
                            .padding(.top, 8)
                    }
                    .multilineTextAlignment(.leading)
                    .sunanHeader(t, gold: true)

                    VStack(spacing: 8) {
                        ForEach(period.times) { tm in
                            SunanLink(.dayTime(tm.id)) {
                                HStack(spacing: 12) {
                                    Text(tm.title).font(AppFont.serif(18)).foregroundStyle(t.cream)
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 4)
                                    Text("\(SunanText.count(tm.items.count, SunanText.sunan)) ←").font(AppFont.sans(12)).foregroundStyle(t.gold).fixedSize()
                                }
                                .sunanRow(t)
                            }
                        }
                    }
                    .padding(.top, 16)

                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        if let prev {
                            SunanBackLink(text: "→ \(SunanText.periodParts(prev.title).name)") { nav.replaceLast(.dayPeriod(prev.id)) }
                        }
                        SunanBackLink(text: SunanText.dayTitle) { nav.open(.day) }
                        if let next {
                            SunanBackLink(text: "\(SunanText.periodParts(next.title).name) ←") { nav.replaceLast(.dayPeriod(next.id)) }
                        }
                    }
                    .padding(.top, 32)
                }
                .padding(16).padding(.bottom, 24)
            }
        }
    }
}

/// /sunan/day/<time> — app/sunan/day/[time]/page.tsx: every item of a time, then previous · its category · next
/// (siblings within the same main category).
struct SunanDayTimeView: View {
    @Environment(\.colorScheme) private var scheme
    let timeId: Int
    var body: some View {
        let t = Theme(scheme)
        SunanLoader(key: "day", load: { try await SunanStore.shared.day() }) { day in
            SunanDayTimeContent(day: day, timeId: timeId)
        }
        .sunanScreen(SunanText.dayTitle, t)
    }
}

private struct SunanDayTimeContent: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var nav: AppNav
    let day: SunanDayFile
    let timeId: Int

    var body: some View {
        let t = Theme(scheme)
        let period = day.periods.first { p in p.times.contains { $0.id == timeId } }
        ScrollView {
            if let period, let k = period.times.firstIndex(where: { $0.id == timeId }) {
                let times = period.times
                let time = times[k]
                let prev = k > 0 ? times[k - 1] : nil
                let next = k + 1 < times.count ? times[k + 1] : nil
                let periodName = SunanText.periodParts(period.title).name
                VStack(alignment: .leading, spacing: 0) {
                    CrumbsView(trail: [.sunanHome, Crumb(SunanText.dayTitle, .day), Crumb(periodName, .dayPeriod(period.id))], current: time.title)
                        .padding(.bottom, 16)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(period.title).font(AppFont.sans(14)).foregroundStyle(t.gold)
                        Text(time.title).font(AppFont.serif(30)).foregroundStyle(t.cream).lineSpacing(4)
                        Text("\(SunanText.count(time.items.count, SunanText.sunan))، «ابدأ بهذه» أولًا كما رتّبها البرنامج:")
                            .font(AppFont.sans(16)).foregroundStyle(t.cream.opacity(0.9)).lineSpacing(6)
                            .padding(.top, 8)
                        dayLegend(t, size: 12).padding(.top, 4)
                    }
                    .multilineTextAlignment(.leading)
                    .sunanHeader(t, gold: true)

                    LazyVStack(spacing: 12) {
                        ForEach(Array(time.items.enumerated()), id: \.offset) { i, it in
                            SunanDayCardView(item: it, n: i + 1)
                        }
                    }
                    .padding(.top, 16)

                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        if let prev {
                            SunanBackLink(text: "→ \(prev.title)") { nav.replaceLast(.dayTime(prev.id)) }
                        }
                        SunanBackLink(text: periodName) { nav.open(.dayPeriod(period.id)) }
                        if let next {
                            SunanBackLink(text: "\(next.title) ←") { nav.replaceLast(.dayTime(next.id)) }
                        }
                    }
                    .padding(.top, 32)
                }
                .padding(16).padding(.bottom, 24)
            }
        }
    }
}

/// SunanDayCard — «ماذا تفعل» in gold → «ثمرته» in green, «طريقة التطبيق», the source, and «تنفعك في» chips.
struct SunanDayCardView: View {
    @Environment(\.colorScheme) private var scheme
    let item: SunanDayItem
    var n: Int? = nil
    private let repo = SunanRepo.shared

    var body: some View {
        let t = Theme(scheme)
        let star = item.star == true
        let needs = (item.needIds ?? []).compactMap { repo.need($0) }
        VStack(alignment: .leading, spacing: 0) {
            SunanLink(.item(fp: item.fp, stateId: item.stateId)) {
                VStack(alignment: .leading, spacing: 8) {
                    if star || n != nil {
                        HStack(spacing: 8) {
                            if let n { Text("\(n)").font(AppFont.sans(12)).foregroundStyle(t.muted) }
                            if star { StarBadge() }
                        }
                    }
                    Text(SunanText.todo(item.todo, fruit: item.fruit, t)).font(AppFont.sans(18)).lineSpacing(9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let apply = item.apply { ApplyBox(apply: apply) }
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(SunanText.sourceOf(grade: item.grade, srcLabel: item.srcLabel)).foregroundStyle(t.muted)
                        Spacer(minLength: 0)
                        Text("التفاصيل والنص ←").foregroundStyle(t.gold).fixedSize()
                    }
                    .font(AppFont.sans(12))
                }
                .multilineTextAlignment(.leading)
                .padding(16).padding(.bottom, needs.isEmpty ? 0 : -8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            if !needs.isEmpty {
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    Text("تنفعك في:").font(AppFont.sans(12)).foregroundStyle(t.muted).padding(.vertical, 7)
                    ForEach(needs) { need in
                        SunanLink(.need(need.id)) { SunanChip(text: need.title) }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 12).padding(.top, 8)
            }
        }
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(star ? t.gold.opacity(0.45) : t.line, lineWidth: 1))
    }
}

/// /sunan/deeds — app/sunan/deeds/page.tsx: «فهرس الأعمال», good deeds then sins.
struct SunanDeedsView: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let t = Theme(scheme)
        SunanLoader(key: "deeds", load: { try await SunanStore.shared.deeds() }) { file in
            SunanDeedsContent(file: file)
        }
        .sunanScreen(SunanText.deedsTitle, t)
    }
}

private struct SunanDeedsContent: View {
    @Environment(\.colorScheme) private var scheme
    let file: SunanDeedsFile

    var body: some View {
        let t = Theme(scheme)
        let good = file.deeds.filter { !$0.sin }
        let sins = file.deeds.filter(\.sin)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                CrumbsView(trail: [.sunanHome], current: SunanText.deedsTitle)
                VStack(alignment: .leading, spacing: 0) {
                    Text(SunanText.deedsTitle).font(AppFont.serif(30)).foregroundStyle(t.cream).lineSpacing(4)
                    Text(SunanText.deedsLead).font(AppFont.sans(16)).foregroundStyle(t.cream.opacity(0.9)).lineSpacing(8)
                        .padding(.top, 12)
                    Text("\(SunanText.deedKind("good")): \(SunanText.count(good.count, SunanText.deeds)) · \(SunanText.deedKind("sin")): \(SunanText.count(sins.count, SunanText.deeds))")
                        .font(AppFont.sans(14)).foregroundStyle(t.muted)
                        .padding(.top, 8)
                }
                .multilineTextAlignment(.leading)
                .sunanHeader(t, gold: true)

                if !good.isEmpty {
                    SunanHeading(text: "\(SunanText.deedKind("good")): ماذا يجلب لك؟", size: 24).padding(.top, 32)
                    LazyVStack(spacing: 12) {
                        ForEach(good) { d in SunanLink(.deed(d.id)) { DeedCard(deed: d) } }
                    }
                    .padding(.top, 16)
                }
                if !sins.isEmpty {
                    SunanHeading(text: "\(SunanText.deedKind("sin")): ماذا يجرّ عليك؟", size: 24).padding(.top, 40)
                    LazyVStack(spacing: 12) {
                        ForEach(sins) { d in SunanLink(.deed(d.id)) { DeedCard(deed: d) } }
                    }
                    .padding(.top, 16)
                }
            }
            .padding(16).padding(.bottom, 24)
        }
    }
}

private struct DeedCard: View {
    @Environment(\.colorScheme) private var scheme
    let deed: SunanDeed
    var body: some View {
        let t = Theme(scheme)
        VStack(alignment: .leading, spacing: 8) {
            Text(deed.title).font(AppFont.serif(21)).foregroundStyle(t.cream)
            if let h = deed.highlights, !h.isEmpty {
                Text(h).font(AppFont.sans(14)).foregroundStyle(t.muted).lineSpacing(6).lineLimit(2)
            }
            Rectangle().fill(t.line).frame(height: 1).padding(.top, 2)
            HStack {
                Text(SunanText.deedCountLine(deed))
                Spacer(minLength: 8)
                Text("افتح ←")
            }
            .font(AppFont.sans(12)).foregroundStyle(t.gold)
        }
        .multilineTextAlignment(.leading)
        .sunanRow(t, border: deed.sin ? t.line : t.gold.opacity(0.35), avoid: deed.sin, h: 20, v: 16, radius: 16)
    }
}

/// /sunan/deeds/<deed> — app/sunan/deeds/[deed]/page.tsx: every fruit (or consequence) of a deed.
struct SunanDeedView: View {
    @Environment(\.colorScheme) private var scheme
    let deedId: Int
    var body: some View {
        let t = Theme(scheme)
        SunanLoader(key: "deeds", load: { try await SunanStore.shared.deeds() }) { file in
            SunanDeedContent(deed: file.deeds.first { $0.id == deedId })
        }
        .sunanScreen(SunanText.deedsTitle, t)
    }
}

private struct SunanDeedContent: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var nav: AppNav
    let deed: SunanDeed?

    var body: some View {
        let t = Theme(scheme)
        ScrollView {
            if let deed {
                VStack(alignment: .leading, spacing: 0) {
                    CrumbsView(trail: [.sunanHome, Crumb(SunanText.deedsTitle, .deeds)], current: deed.title)
                        .padding(.bottom, 16)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(SunanText.deedKind(deed.kind)).font(AppFont.sans(14)).foregroundStyle(t.gold)
                        Text(deed.title).font(AppFont.serif(30)).foregroundStyle(t.cream).lineSpacing(4)
                        Text("\(SunanText.deedCountLine(deed))، \(deed.sin ? "كل عاقبةٍ" : "كل ثمرةٍ") بسنّتها ومصدرها:")
                            .font(AppFont.sans(16)).foregroundStyle(t.cream.opacity(0.9)).lineSpacing(6)
                            .padding(.top, 8)
                        RunsLegend().padding(.top, 8)
                    }
                    .multilineTextAlignment(.leading)
                    .sunanHeader(t, gold: !deed.sin, avoid: deed.sin)

                    LazyVStack(spacing: 12) {
                        ForEach(Array(deed.items.enumerated()), id: \.offset) { i, it in
                            SunanDeedCardView(item: it, sin: deed.sin, n: i + 1)
                        }
                    }
                    .padding(.top, 16)

                    SunanBackLink(text: "→ بقية الأعمال") { nav.open(.deeds) }
                        .padding(.top, 32)
                }
                .padding(16).padding(.bottom, 24)
            }
        }
    }
}

/// SunanDeedCard — the fruit, the sunnah's easy line, the source, and where it lives (need › state).
struct SunanDeedCardView: View {
    @Environment(\.colorScheme) private var scheme
    let item: SunanDeedItem
    let sin: Bool
    var n: Int? = nil
    private let repo = SunanRepo.shared

    var body: some View {
        let t = Theme(scheme)
        let need = repo.need(item.needId)
        let state = repo.state(item.stateId)
        VStack(alignment: .leading, spacing: 0) {
            SunanLink(.item(fp: item.fp, stateId: item.stateId)) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        if let n { Text("\(n)").foregroundStyle(t.muted) }
                        Text(sin ? "عاقبته" : "ثمرته").foregroundStyle(sin ? t.error : t.result)
                        if item.ijtihad == true { IjtihadBadge() }
                    }
                    .font(AppFont.sans(12))
                    Text(item.fruit).font(AppFont.serif(20)).foregroundStyle(sin ? t.cream : t.result).lineSpacing(6)
                    Text(SunanText.easy(item.easy, t)).font(AppFont.sans(16)).lineSpacing(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(SunanText.sourceOf(grade: item.grade, srcLabel: item.srcLabel)).foregroundStyle(t.muted)
                        Spacer(minLength: 0)
                        Text("التفاصيل والنص ←").foregroundStyle(t.gold).fixedSize()
                    }
                    .font(AppFont.sans(12))
                    .padding(.top, 6)
                }
                .multilineTextAlignment(.leading)
                .padding(16).padding(.bottom, need != nil && state != nil ? -8 : 0)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            if let need, let state {
                FlowLayout(spacing: 6, lineSpacing: 4) {
                    SunanLink(.need(need.id)) {
                        Text(need.title).foregroundStyle(t.gold.opacity(0.9)).underline(color: t.gold.opacity(0.3))
                    }
                    Text("›").foregroundStyle(t.muted)
                    SunanLink(.state(state.id)) {
                        Text(state.title).foregroundStyle(t.gold.opacity(0.9)).underline(color: t.gold.opacity(0.3))
                    }
                }
                .font(AppFont.sans(12))
                .padding(.horizontal, 16).padding(.bottom, 12).padding(.top, 8)
            }
        }
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.line, lineWidth: 1))
    }
}
