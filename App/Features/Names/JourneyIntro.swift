import SwiftUI

/// «رحلة الحسنى» — the owner's map (2026-11-24) as the introduction to «كنز الأسماء الحسنى». Owner 2026-11-25: it is never
/// forced — the section home invites to it («ما أهمية الأسماء الحسنى؟»), and the whole road is one page: each station
/// opens on a tap (its verses in full, «ماذا تعمل؟» and «كيف تستفيد؟»), then the end of the road and «ادخل القسم».
/// The texts and verses are generated from the owner's file (HusnaJourneyData.swift); the verses match quran.json.
/// «رحلة باسم ربك» (owner 2026-11-25, BismJourneyData.swift) is the second journey: offered at the end of the first,
/// and as a small line at the top of the section.
struct Journey {
    let title: String
    let lead: String
    let stations: [JourneyStation]
    let endKicker: String
    let endTitle: String
    let endText: String
    let summaryTitle: String
    let summary: [String]
    /// Empty ⇒ not shown.
    let closing: String
    let footnote: String
    /// The verse of the end of the road («رحلة باسم ربك»: مريم 65), under its title.
    var endVerse: JourneyVerse? = nil
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
    /// Set once the visitor started the journey or chose «ليس الآن»: the invitation card becomes a small line.
    static let seenKey = "namesIntroSeen"
    /// CI: `-route namesintro` (the road), `namesintro1`…`namesintro5` (a station opened), `namesintro6` (the end);
    /// `bismintro…` the same for «رحلة باسم ربك».
    static var ciFocus: Int? {
        let a = Route.arg
        guard Route.isCI, let p = ["namesintro", "bismintro"].first(where: { a.hasPrefix($0) }), a != "namesintroseen"
        else { return nil }
        let rest = a.dropFirst(p.count)
        return rest.isEmpty ? 0 : Int(rest)
    }
    /// CI: which journey the route opens.
    static var ciBism: Bool { Route.isCI && Route.arg.hasPrefix("bismintro") }
    /// CI: `-route namesintroseen` — the section home after the invitation.
    static var ciSeen: Bool { Route.isCI && Route.arg == "namesintroseen" }
    /// The CI journey opens once (the section home appears again when it closes).
    static var ciOpened = false
}

/// The road on one page: the stations one under the other, each opening on a tap; then the end of the road.
struct JourneyIntroView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var journey: Journey
    /// The journey offered at the end of the road («الرحلة التالية»), if any.
    @State private var next: Journey?
    /// CI only: a station to open (1…5) or the end of the road (stations + 1).
    let focus: Int
    @State private var open: Int?

    init(journey: Journey, next: Journey? = nil, focus: Int = 0) {
        _journey = State(initialValue: journey)
        _next = State(initialValue: next)
        self.focus = focus
        _open = State(initialValue: (1...max(1, journey.stations.count)).contains(focus) ? focus : nil)
    }

    var body: some View {
        let t = Theme(scheme)
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: { Text("→ رجوع") }
                    .font(AppFont.sans(15)).foregroundStyle(t.gold)
                    .frame(minHeight: 40)
                Spacer()
            }
            .padding(.horizontal, 20).padding(.top, 8)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        header(t).id("top")
                        stations(t).padding(.top, 24)
                        end(t).padding(.top, 24).id("end")
                        if let n = next {
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    journey = n
                                    next = nil
                                    open = nil
                                }
                                proxy.scrollTo("top", anchor: .top)
                            } label: { Text("الرحلة التالية: \(n.title) ←").frame(maxWidth: .infinity) }
                                .buttonStyle(PrimaryPill())
                                .padding(.top, 20)
                            Button { dismiss() } label: { Text("ادخل القسم ←").frame(maxWidth: .infinity) }
                                .buttonStyle(SecondaryPill())
                                .padding(.top, 10)
                        } else {
                            Button { dismiss() } label: { Text("ادخل القسم ←").frame(maxWidth: .infinity) }
                                .buttonStyle(PrimaryPill())
                                .padding(.top, 20)
                        }
                    }
                    .padding(16).padding(.bottom, 16)
                }
                .task {
                    guard focus > 0 else { return }
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    proxy.scrollTo(focus > journey.stations.count ? "end" : "s\(focus)", anchor: .top)
                }
            }
        }
        .background(t.bg.ignoresSafeArea())
    }

    // MARK: - The title of the road

    private func header(_ t: Theme) -> some View {
        VStack(spacing: 0) {
            BrandMark(color: t.gold).frame(width: 48, height: 48)
            Text(journey.title).font(AppFont.serif(34)).foregroundStyle(t.cream).padding(.top, 14)
            Text(journey.lead).font(AppFont.sans(16)).foregroundStyle(t.muted).lineSpacing(7).padding(.top, 8)
            Text("المس أي محطة لتنفتح").font(AppFont.sans(13)).foregroundStyle(t.gold).padding(.top, 10)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    // MARK: - The stations

    private func stations(_ t: Theme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(journey.stations) { s in
                station(s, t).id("s\(s.n)")
            }
        }
        // the road: a line through the stations' numbers, seen between the cards
        .background(alignment: .leading) {
            Rectangle().fill(t.gold.opacity(0.45)).frame(width: 2)
                .padding(.vertical, 30)
                .padding(.leading, 32)
        }
    }

    private func station(_ s: JourneyStation, _ t: Theme) -> some View {
        let on = open == s.n
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { open = on ? nil : s.n }
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    Text("\(s.n)").font(AppFont.sans(16, .bold))
                        .foregroundStyle(s.side ? t.gold : t.bg)
                        .frame(width: 38, height: 38)
                        .background(s.side ? Color.clear : t.gold, in: Circle())
                        .overlay(Circle().stroke(t.gold, style: StrokeStyle(lineWidth: 1.5, dash: s.side ? [4, 3] : [])))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(s.name.isEmpty ? s.verb : "\(s.verb) · \(s.name)").font(AppFont.sans(13, .medium)).foregroundStyle(t.gold)
                        Text(s.title).font(AppFont.serif(20)).foregroundStyle(t.cream).lineSpacing(3)
                        Text(s.count).font(AppFont.sans(12.5)).foregroundStyle(t.muted)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.down").font(.system(size: 13, weight: .semibold)).foregroundStyle(t.gold)
                        .rotationEffect(.degrees(on ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if on {
                VStack(alignment: .leading, spacing: 0) {
                    Text(s.text).font(AppFont.sans(16)).foregroundStyle(t.cream.opacity(0.9)).lineSpacing(7)
                        .padding(.top, 14)
                    Rectangle().fill(t.line).frame(height: 1).padding(.top, 14)
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(s.verses) { v in
                            VStack(alignment: .leading, spacing: 6) {
                                if let l = v.label {
                                    Text(l).font(AppFont.sans(14, .bold)).foregroundStyle(t.gold)
                                }
                                Text("﴿\(v.text)﴾").font(AppFont.amiri(20)).foregroundStyle(t.cream).lineSpacing(10)
                                Text("[\(v.ref)]" + (v.note.map { " · \($0)" } ?? ""))
                                    .font(AppFont.sans(13)).foregroundStyle(t.gold)
                            }
                        }
                    }
                    .padding(.top, 14)
                    VStack(spacing: 8) {
                        box("ماذا تعمل؟", s.doIt, t)
                        box("كيف تستفيد؟", s.gain, t)
                    }
                    .padding(.top, 18)
                }
                .transition(.opacity)
            }
        }
        .multilineTextAlignment(.leading)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18)
            .stroke(on ? t.gold : t.gold.opacity(s.side ? 0.7 : 0.25),
                    style: StrokeStyle(lineWidth: on || s.side ? 1.5 : 1, dash: s.side ? [6, 5] : [])))
    }

    private func box(_ label: String, _ value: String, _ t: Theme) -> some View {
        (Text(label + " ").font(AppFont.sans(15, .bold)).foregroundColor(t.gold)
            + Text(value).font(AppFont.sans(16)).foregroundColor(t.cream))
            .lineSpacing(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(t.gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - The end of the road

    private func end(_ t: Theme) -> some View {
        let cream = Color(hex: 0xF7ECD6)
        return VStack(spacing: 0) {
            VStack(spacing: 14) {
                Text(journey.endKicker).font(AppFont.sans(16, .bold))
                Text(journey.endTitle).font(AppFont.serif(journey.endTitle.count > 10 ? 40 : 60)).lineSpacing(4)
                if let v = journey.endVerse {
                    VStack(spacing: 6) {
                        Text("﴿\(v.text)﴾").font(AppFont.amiri(21)).lineSpacing(10)
                        Text("[\(v.ref)]").font(AppFont.sans(13, .medium))
                    }
                }
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
                if !journey.closing.isEmpty {
                    Text(journey.closing).font(AppFont.serif(24)).lineSpacing(6).padding(.top, 6)
                }
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
