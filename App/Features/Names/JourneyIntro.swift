import SwiftUI

/// «رحلة الحسنى» — the owner's map (2026-11-24) as the introduction to «كنز الأسماء الحسنى»: whoever enters the section
/// sees it once (the road → five stations → the end of the road), and can open it again from the section home.
/// The texts and verses are generated from the owner's file (HusnaJourneyData.swift); the verses match quran.json.
struct Journey {
    let title: String
    let lead: String
    let stations: [JourneyStation]
    let endKicker: String
    let endTitle: String
    let endText: String
    let summaryTitle: String
    let summary: [String]
    let closing: String
    let footnote: String
}

struct JourneyStation: Identifiable {
    let n: Int
    let name: String
    let verb: String
    let count: String
    /// «طريق جانبي» — drawn dashed, as on the map.
    let side: Bool
    let title: String
    let text: String
    let verses: [JourneyVerse]
    let doIt: String
    let gain: String
    var id: Int { n }
}

struct JourneyVerse: Identifiable {
    let label: String?
    let text: String
    let ref: String
    let note: String?
    var id: String { ref }
}

enum NamesIntro {
    static let seenKey = "namesIntroSeen"
    /// Once per launch at most (the section home appears again when its pages are popped).
    static var offeredThisLaunch = false
    /// CI: `-route namesintro` (the road), `namesintro1`…`namesintro5` (a station), `namesintro6` (the end).
    static var ciPage: Int? {
        let a = Route.arg
        guard Route.isCI, a.hasPrefix("namesintro") else { return nil }
        return Int(a.dropFirst("namesintro".count)) ?? 0
    }
    /// The first entry into the section (never in other CI screenshots).
    static var due: Bool {
        if offeredThisLaunch { return false }
        if Route.isCI { return ciPage != nil }
        return !UserDefaults.standard.bool(forKey: seenKey)
    }
}

/// The introduction, page by page: swipe or use «التالي» / «السابق»; «تخطَّ» or «ادخل القسم» closes it for good.
struct JourneyIntroView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    let journey: Journey
    @State private var page: Int?

    init(journey: Journey, startPage: Int = 0) {
        self.journey = journey
        _page = State(initialValue: startPage)
    }

    private var pages: Int { journey.stations.count + 2 }

    var body: some View {
        let t = Theme(scheme)
        let current = page ?? 0
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    ForEach(0..<pages, id: \.self) { i in
                        Capsule().fill(i == current ? t.gold : t.line)
                            .frame(width: i == current ? 18 : 6, height: 6)
                    }
                }
                .animation(.easeOut(duration: 0.2), value: current)
                Spacer()
                Button("تخطَّ") { finish() }
                    .font(AppFont.sans(15)).foregroundStyle(t.muted)
                    .frame(minHeight: 40)
            }
            .padding(.horizontal, 20).padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(0..<pages, id: \.self) { i in
                        pageView(i, t)
                            .containerRelativeFrame(.horizontal)
                            .id(i)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $page)

            HStack(spacing: 12) {
                if current > 0 {
                    Button { go(current - 1) } label: { Text("→ السابق") }.buttonStyle(SecondaryPill(compact: true))
                }
                Spacer()
                if current < pages - 1 {
                    Button { go(current + 1) } label: { Text(current == 0 ? "ابدأ الرحلة ←" : "التالي ←") }
                        .buttonStyle(PrimaryPill(compact: true))
                } else {
                    Button { finish() } label: { Text("ادخل القسم ←") }.buttonStyle(PrimaryPill(compact: true))
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
        .background(t.bg.ignoresSafeArea())
    }

    @ViewBuilder
    private func pageView(_ i: Int, _ t: Theme) -> some View {
        ScrollView {
            Group {
                if i == 0 {
                    road(t)
                } else if i <= journey.stations.count {
                    station(journey.stations[i - 1], t)
                } else {
                    end(t)
                }
            }
            .padding(16).padding(.bottom, 8)
        }
    }

    private func go(_ i: Int) {
        withAnimation(.easeInOut(duration: 0.3)) { page = i }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: NamesIntro.seenKey)
        dismiss()
    }

    // MARK: - The road (the map at a glance)

    private func road(_ t: Theme) -> some View {
        VStack(spacing: 0) {
            BrandMark(color: t.gold).frame(width: 56, height: 56)
            Text(journey.title).font(AppFont.serif(36)).foregroundStyle(t.cream).padding(.top, 16)
            Text(journey.lead)
                .font(AppFont.sans(17)).foregroundStyle(t.muted).lineSpacing(7)
                .padding(.top, 10)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(journey.stations) { s in
                    stop(t, line: true, dashedLine: journey.stations.last?.id == s.id || nextIsSide(s)) {
                        Text("\(s.n)").font(AppFont.sans(17, .bold))
                            .foregroundStyle(s.side ? t.gold : t.bg)
                            .frame(width: 42, height: 42)
                            .background(s.side ? Color.clear : t.gold, in: Circle())
                            .overlay(Circle().stroke(t.gold, style: StrokeStyle(lineWidth: 1.5, dash: s.side ? [4, 3] : [])))
                    } label: {
                        HStack(spacing: 8) {
                            Text(s.verb).font(AppFont.serif(22)).foregroundStyle(t.cream)
                            if s.side {
                                Text("طريق جانبي").font(AppFont.sans(12)).foregroundStyle(t.gold)
                                    .padding(.horizontal, 8).padding(.vertical, 2)
                                    .overlay(Capsule().stroke(t.gold.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                            }
                        }
                        Text(s.name).font(AppFont.sans(14)).foregroundStyle(t.muted)
                    }
                }
                stop(t, line: false, dashedLine: false) {
                    BrandMark(color: Palette.night, lineWidth: 4)
                        .frame(width: 26, height: 26)
                        .frame(width: 42, height: 42)
                        .background(Color(hex: 0xD4A449), in: Circle())
                } label: {
                    Text(journey.endTitle).font(AppFont.serif(22)).foregroundStyle(t.gold)
                    Text(journey.endKicker).font(AppFont.sans(14)).foregroundStyle(t.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 28)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 8).padding(.top, 12)
    }

    private func nextIsSide(_ s: JourneyStation) -> Bool {
        journey.stations.first { $0.n == s.n + 1 }?.side ?? false
    }

    private func stop<Mark: View, Label: View>(_ t: Theme, line: Bool, dashedLine: Bool,
                                               @ViewBuilder mark: () -> Mark,
                                               @ViewBuilder label: () -> Label) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                mark()
                if line {
                    Path { p in
                        p.move(to: CGPoint(x: 1, y: 0))
                        p.addLine(to: CGPoint(x: 1, y: 26))
                    }
                    .stroke(t.gold.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: dashedLine ? [4, 4] : []))
                    .frame(width: 2, height: 26)
                }
            }
            VStack(alignment: .leading, spacing: 2) { label() }
                .multilineTextAlignment(.leading)
                .padding(.top, 4)
        }
    }

    // MARK: - A station

    private func station(_ s: JourneyStation, _ t: Theme) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text(s.verb).font(AppFont.sans(15, .bold))
                    .foregroundStyle(s.side ? t.gold : t.bg)
                    .padding(.horizontal, 14).padding(.vertical, 4)
                    .background(s.side ? Color.clear : t.gold, in: Capsule())
                    .overlay(Capsule().stroke(t.gold, style: StrokeStyle(lineWidth: 1.5, dash: s.side ? [4, 3] : [])))
                Text("\(s.n) · \(s.name)").font(AppFont.sans(14)).foregroundStyle(t.gold)
                Spacer(minLength: 8)
                Text(s.count).font(AppFont.sans(13)).foregroundStyle(t.muted)
            }
            Text(s.title).font(AppFont.serif(30)).foregroundStyle(t.cream).lineSpacing(4)
                .padding(.top, 16)
            Text(s.text).font(AppFont.sans(17)).foregroundStyle(t.cream.opacity(0.9)).lineSpacing(8)
                .padding(.top, 10)

            Rectangle().fill(t.line).frame(height: 1).padding(.top, 18)
            VStack(alignment: .leading, spacing: 20) {
                ForEach(s.verses) { v in
                    VStack(alignment: .leading, spacing: 6) {
                        if let l = v.label {
                            Text(l).font(AppFont.sans(14, .bold)).foregroundStyle(t.gold)
                        }
                        Text("﴿\(v.text)﴾").font(AppFont.amiri(21)).foregroundStyle(t.cream).lineSpacing(10)
                        Text("[\(v.ref)]" + (v.note.map { " · \($0)" } ?? ""))
                            .font(AppFont.sans(13)).foregroundStyle(t.gold)
                    }
                }
            }
            .padding(.top, 18)

            VStack(spacing: 10) {
                box("ماذا تعمل؟", s.doIt, t)
                box("كيف تستفيد؟", s.gain, t)
            }
            .padding(.top, 22)
        }
        .multilineTextAlignment(.leading)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20)
            .stroke(t.gold.opacity(s.side ? 0.7 : 0.3), style: StrokeStyle(lineWidth: s.side ? 1.5 : 1, dash: s.side ? [6, 5] : [])))
    }

    private func box(_ label: String, _ value: String, _ t: Theme) -> some View {
        (Text(label + " ").font(AppFont.sans(15, .bold)).foregroundColor(t.gold)
            + Text(value).font(AppFont.sans(16)).foregroundColor(t.cream))
            .lineSpacing(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(t.gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - The end of the road

    private func end(_ t: Theme) -> some View {
        let cream = Color(hex: 0xF7ECD6)
        return VStack(spacing: 0) {
            VStack(spacing: 14) {
                Text(journey.endKicker).font(AppFont.sans(16, .bold))
                Text(journey.endTitle).font(AppFont.serif(60))
                Text(journey.endText).font(AppFont.sans(19, .medium)).lineSpacing(6)
                Rectangle().fill(Palette.night.opacity(0.25)).frame(height: 1).padding(.vertical, 4)
                Text(journey.summaryTitle).font(AppFont.sans(15, .bold))
                VStack(spacing: 8) {
                    ForEach(Array(journey.summary.enumerated()), id: \.offset) { i, line in
                        let side = i == journey.summary.count - 1
                        Text(line).font(AppFont.sans(17, .medium))
                            .foregroundStyle(side ? Palette.night : cream)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(side ? Color.clear : Palette.night, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(side ? Palette.night : Color.clear, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                    }
                }
                Text(journey.closing).font(AppFont.serif(24)).lineSpacing(6).padding(.top, 6)
            }
            .foregroundStyle(Palette.night)
            .multilineTextAlignment(.center)
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(Color(hex: 0xD4A449), in: RoundedRectangle(cornerRadius: 24))

            Text(journey.footnote)
                .font(AppFont.sans(12.5)).foregroundStyle(t.muted).lineSpacing(5)
                .multilineTextAlignment(.center)
                .padding(.top, 16).padding(.horizontal, 8)
        }
    }
}
