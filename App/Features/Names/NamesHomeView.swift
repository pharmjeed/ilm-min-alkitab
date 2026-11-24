import SwiftUI

/// The website's home page (app/page.tsx): hero → «ماذا تشعر الآن؟» → «اسم اليوم» (the «اسأل عن موقفك» card was removed
/// at the owner's request 2026-11-24; the hero button still opens «اسأل»).
/// («تصفّح بالمصحف» is not part of the app.)
struct NamesHomeView: View {
    @Environment(\.colorScheme) private var scheme
    private let repo = NamesRepo.shared
    /// «رحلة الحسنى» — opened from «ما أهمية الأسماء الحسنى؟» at the top of the section (owner 2026-11-25).
    @State private var showIntro = false
    @AppStorage(NamesIntro.seenKey) private var introSeen = false

    var body: some View {
        let t = Theme(scheme)
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    IntroInvite(seen: introSeen || NamesIntro.ciSeen, lead: Journey.husna.lead) {
                        introSeen = true
                        showIntro = true
                    } later: {
                        withAnimation(.easeInOut(duration: 0.25)) { introSeen = true }
                    }
                    .padding(.bottom, 16)
                    HeroSection()
                    FeelEntry(heading: false).padding(.top, 24)
                    if let nod = repo.nameOfDay() {
                        NameOfDaySection(card: nod).padding(.top, 48).id("nod")
                    }
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .task {
                guard Route.scrollToNameOfDay else { return }
                try? await Task.sleep(nanoseconds: 600_000_000)
                proxy.scrollTo("nod", anchor: .top)
            }
        }
        .namesScreen("كنز الأسماء الحسنى", t)
        .onAppear {
            guard NamesIntro.ciFocus != nil, !NamesIntro.ciOpened else { return }
            NamesIntro.ciOpened = true
            showIntro = true
        }
        .fullScreenCover(isPresented: $showIntro) {
            JourneyIntroView(journey: .husna, focus: NamesIntro.ciFocus ?? 0)
                .environment(\.layoutDirection, .rightToLeft)
        }
    }
}

/// «ما أهمية الأسماء الحسنى؟» (owner 2026-11-25): a clear card at the top of the section until the visitor starts the
/// journey or chooses «ليس الآن»; then a small line in its place, for whoever wants to come back to it.
private struct IntroInvite: View {
    @Environment(\.colorScheme) private var scheme
    let seen: Bool
    let lead: String
    let start: () -> Void
    let later: () -> Void

    var body: some View {
        let t = Theme(scheme)
        if seen {
            Button(action: start) {
                HStack(spacing: 6) {
                    Image(systemName: "map")
                    Text("ما أهمية الأسماء الحسنى؟ ←")
                }
                .font(AppFont.sans(15)).foregroundStyle(t.gold)
                .padding(.horizontal, 14).frame(minHeight: 40)
                .overlay(Capsule().stroke(t.gold.opacity(0.45), lineWidth: 1))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: "map").font(.system(size: 22)).foregroundStyle(t.gold)
                Text("ما أهمية الأسماء الحسنى؟").font(AppFont.serif(24)).foregroundStyle(t.cream)
                    .padding(.top, 10)
                Text(lead).font(AppFont.sans(15)).foregroundStyle(t.muted).lineSpacing(6)
                    .padding(.top, 6)
                Button(action: start) { Text("ابدأ الرحلة · دقيقتان ←").frame(maxWidth: .infinity) }
                    .buttonStyle(PrimaryPill())
                    .padding(.top, 16)
                Button(action: later) {
                    Text("ليس الآن").font(AppFont.sans(15)).foregroundStyle(t.gold)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(t.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(t.gold, lineWidth: 1.5))
        }
    }
}

/// components/home/HomeSections.tsx HeroSection (hero settings: title and the two buttons).
private struct HeroSection: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var nav: AppNav
    @State private var query = ""

    var body: some View {
        let t = Theme(scheme)
        VStack(spacing: 0) {
            BrandMark(color: t.gold).frame(width: 56, height: 56).padding(.bottom, 20)
            Text("﴿وَلِلَّهِ الْأَسْمَاءُ الْحُسْنَىٰ فَادْعُوهُ بِهَا﴾")
                .font(AppFont.amiri(26)).foregroundStyle(t.gold)
                .multilineTextAlignment(.center).lineSpacing(8)
            Text("أسماء الله الحسنى كما وردت في القرآن")
                .font(AppFont.serif(36)).foregroundStyle(t.cream)
                .multilineTextAlignment(.center).lineSpacing(4)
                .padding(.top, 16)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(t.muted)
                TextField("", text: $query, prompt: Text("ابحث عن اسم، أو كلمة من آية، أو مرجع مثل: البقرة 255").foregroundColor(t.muted))
                    .font(AppFont.sans(16)).foregroundStyle(t.cream)
                    .submitLabel(.search)
                    .onSubmit { nav.open(.allNames(query: query)) }
            }
            .padding(.horizontal, 16).frame(minHeight: 52)
            .background(t.bg.opacity(0.4), in: Capsule())
            .overlay(Capsule().stroke(t.line, lineWidth: 1))
            .padding(.top, 28)
            HStack(spacing: 12) {
                NavigationLink(value: HomeDestination.n(.allNames())) { Text("تصفّح الأسماء") }.buttonStyle(PrimaryPill())
                NavigationLink(value: HomeDestination.n(.ask())) { Text("اسأل عن موقفك") }.buttonStyle(SecondaryPill())
            }
            .padding(.top, 24)
        }
        .padding(.horizontal, 20).padding(.vertical, 44)
        .frame(maxWidth: .infinity)
        .background(alignment: .topTrailing) {
            BrandMark(color: t.gold)
                .frame(width: 420, height: 420)
                .opacity(0.06)
                .offset(x: 120, y: -120)
        }
        .clipped()
        .background(t.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(t.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// components/feel/FeelEntry.tsx — the question, the swipeable rail of doors, and «ما بأنفسهم».
struct FeelEntry: View {
    @Environment(\.colorScheme) private var scheme
    /// true on /feel (h1), false on the home page (h2).
    var heading: Bool
    private let repo = NamesRepo.shared

    var body: some View {
        let t = Theme(scheme)
        VStack(spacing: 0) {
            Text("ماذا تشعر الآن؟")
                .font(AppFont.serif(heading ? 34 : 32)).foregroundStyle(t.cream)
                .multilineTextAlignment(.center)
            Text("اختر حالك، ونصل بك إلى الأسماء التي تدعو بها")
                .font(AppFont.sans(14)).foregroundStyle(t.muted)
                .multilineTextAlignment(.center).padding(.top, 8)
            FeelRail(doors: repo.doors).padding(.top, 24)
            if !repo.inner.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        Rectangle().fill(t.line).frame(height: 1)
                        Text("أو ابدأ من قلبك").font(AppFont.sans(12.5)).foregroundStyle(t.muted).fixedSize()
                        Rectangle().fill(t.line).frame(height: 1)
                    }
                    NamesLink(.anfus()) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("ما بأنفسهم").font(AppFont.serif(22)).foregroundStyle(t.gold)
                                Spacer()
                                Text("افتح ←").font(AppFont.sans(12.5)).foregroundStyle(t.gold)
                            }
                            Text("حين يكون ما تحتاج تغييره في نفسك لا في ظرفك: همٌّ في الصدر، أو نفسٌ تغالبها، أو علّةٌ في القلب.")
                                .font(AppFont.sans(16)).foregroundStyle(t.cream.opacity(0.9)).lineSpacing(5)
                            Text(repo.inner.map(\.label).joined(separator: " · "))
                                .font(AppFont.sans(12.5)).foregroundStyle(t.muted).lineSpacing(4).padding(.top, 4)
                        }
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 20).padding(.vertical, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(t.gold.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.gold.opacity(0.45), lineWidth: 1))
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.top, 12)
                }
                .padding(.top, 28)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .background(t.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(t.line, lineWidth: 1))
    }
}

/// components/feel/FeelRail.tsx — swipe sideways, snaps to a card, dots show the position.
private struct FeelRail: View {
    @Environment(\.colorScheme) private var scheme
    let doors: [Door]
    @State private var active: Int?

    var body: some View {
        let t = Theme(scheme)
        VStack(spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(doors) { d in
                        NamesLink(.door(d.id)) { FeelCard(door: d) }
                            .containerRelativeFrame(.horizontal) { w, _ in min(320, w * 0.78) }
                            .frame(maxHeight: .infinity)
                            .id(d.id)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .scrollTargetLayout()
                .padding(.vertical, 4)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $active)
            .padding(.horizontal, -20)
            .contentMargins(.horizontal, 20, for: .scrollContent)

            HStack(spacing: 6) {
                ForEach(doors) { d in
                    let on = (active ?? doors.first?.id) == d.id
                    Capsule()
                        .fill(on ? t.gold : t.line)
                        .frame(width: on ? 20 : 6, height: 6)
                        .onTapGesture { withAnimation { active = d.id } }
                }
            }
            .animation(.easeOut(duration: 0.2), value: active)
        }
    }
}

/// One door: number, label, the website's lead line, its covers as chips, «N حالة · افتح ←».
private struct FeelCard: View {
    @Environment(\.colorScheme) private var scheme
    let door: Door

    var body: some View {
        let t = Theme(scheme)
        VStack(alignment: .leading, spacing: 12) {
            Text("\(door.id)")
                .font(AppFont.sans(16)).foregroundStyle(t.gold)
                .frame(width: 36, height: 36)
                .overlay(Circle().stroke(t.line, lineWidth: 1))
            Text(door.label).font(AppFont.serif(26)).foregroundStyle(t.cream)
            let lead = door.lead ?? door.description
            if !lead.isEmpty {
                Text(lead).font(AppFont.sans(16)).foregroundStyle(t.muted).lineSpacing(5)
            }
            if let covers = door.covers, !covers.isEmpty {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(covers, id: \.self) { c in
                        Text(c)
                            .font(AppFont.sans(13)).foregroundStyle(t.gold.opacity(0.9))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(t.gold.opacity(0.05), in: Capsule())
                            .overlay(Capsule().stroke(t.gold.opacity(0.3), lineWidth: 1))
                    }
                }
            }
            Spacer(minLength: 0)
            VStack(spacing: 12) {
                Rectangle().fill(t.line).frame(height: 1)
                HStack {
                    Text(Arabic.count(door.situationIds.count, Arabic.situations)).foregroundStyle(t.gold)
                    Spacer()
                    Text("افتح ←").foregroundStyle(t.gold)
                }
                .font(AppFont.sans(14))
            }
        }
        .multilineTextAlignment(.leading)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(t.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .trailing) {
            // the gold edge at the card's end (before:end-0 before:w-[3px])
            LinearGradient(colors: [t.gold, t.gold.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 1.5))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(t.gold.opacity(0.35), lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// components/home/HomeSections.tsx NameOfDay.
private struct NameOfDaySection: View {
    @Environment(\.colorScheme) private var scheme
    let card: NameCard
    @State private var detail: NameDetail?

    var body: some View {
        let t = Theme(scheme)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline) {
                Text("اسم اليوم").font(AppFont.serif(26)).foregroundStyle(t.cream)
                Spacer()
                NamesLink(.name(card.id)) { Text("افتح الاسم ←").font(AppFont.sans(14)).foregroundStyle(t.gold) }
            }
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("الاسم رقم \(card.id)").font(AppFont.sans(12.5)).foregroundStyle(t.gold)
                    NamesLink(.name(card.id)) {
                        Text(card.name).font(AppFont.serif(32)).foregroundStyle(t.cream)
                    }
                    .padding(.top, 4)
                    if let d = detail {
                        Text(Arabic.firstLines(d.meaning, 3))
                            .font(AppFont.sans(14)).foregroundStyle(t.muted).lineSpacing(6).padding(.top, 12)
                    }
                    HStack(spacing: 0) {
                        Text("\(card.positions) موضعًا · \(card.surahs) سورة")
                        if card.hadiths > 0 {
                            Text(" · ")
                            NamesLink(.name(card.id, tab: .sunnah)) {
                                Text("\(Arabic.count(card.hadiths, Arabic.witnesses)) من السنة").foregroundStyle(t.gold)
                            }
                        }
                    }
                    .font(AppFont.sans(12.5)).foregroundStyle(t.muted)
                    .padding(.top, 12)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("متى أدعو به؟").font(AppFont.sans(12.5)).foregroundStyle(t.gold)
                    let pray = detail.map { Arabic.firstLines($0.whenPray, 3) } ?? ""
                    Text(pray.isEmpty ? "—" : pray)
                        .font(AppFont.sans(14)).foregroundStyle(t.cream.opacity(0.9)).lineSpacing(9)
                    NamesLink(.name(card.id, tab: .pray)) {
                        Text("اقرأ «متى أدعو به» كاملًا ←").font(AppFont.sans(14)).foregroundStyle(t.gold)
                    }
                    .padding(.top, 4)
                }
                .siteCard(t, radius: 12, fill: t.bg.opacity(0.4))
            }
            .multilineTextAlignment(.leading)
            .siteCard(t, border: t.gold.opacity(0.4), padding: 20)
        }
        .task {
            if detail == nil { detail = try? await NameDetails.shared.detail(card.id) }
        }
    }
}
