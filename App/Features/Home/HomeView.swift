import SwiftUI

/// «الرئيسية»: the two treasures, stacked (owner's choice: one above the other, full width) — no heading and no counts
/// (owner 2026-11-24: «احذف هذه»).
struct HomeView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Spacer()
                    BrandMark(color: t.gold).frame(width: 30, height: 30)
                    Text("علم من الكتاب").font(AppFont.serif(20)).foregroundStyle(t.cream)
                    Spacer()
                }
                .padding(.top, 4).padding(.bottom, 12)

                NavigationLink(value: HomeDestination.names) {
                    TreasureCard(title: "كنز الأسماء الحسنى",
                                 line: "اعرف أسماء الله، وافهمها، واعرف متى تدعوه بها.",
                                 accent: t.gold, fill: t.surface, systemIcon: nil)
                }
                NavigationLink(value: HomeDestination.sunan) {
                    TreasureCard(title: "سر علم السنن والأسباب",
                                 line: "لكل حاجةٍ سببٌ من الكتاب والسنة: افعل كذا، يكن لك كذا.",
                                 // owner 2026-11-25: both cards in one colour (the gold of the names card)
                                 accent: t.gold, fill: t.surface, systemIcon: "book")
                }
            }
            .padding(16)
        }
        .background(t.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: HomeDestination.self) { d in
            switch d {
            case .names: NamesHomeView()
            case .sunan: SunanHomeView()
            case .n(let route): NamesRouteView(route: route)
            case .s(let route): SunanRouteView(route: route)
            }
        }
    }
}

/// Everything the «الرئيسية» stack can show. `.n` / `.s` = a page of the names / sunan section (mirror of the website).
enum HomeDestination: Hashable {
    case names, sunan
    case n(NamesRoute)
    case s(SunanRoute)
}

extension HomeDestination {
    var section: PackSection {
        switch self {
        case .names, .n: return .names
        case .sunan, .s: return .sunan
        }
    }
}

private struct TreasureCard: View {
    let title: String
    let line: String
    let accent: Color
    let fill: Color
    let systemIcon: String?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(accent.opacity(0.12))
                if let systemIcon {
                    Image(systemName: systemIcon).font(.system(size: 22, weight: .medium)).foregroundStyle(accent)
                } else {
                    BrandMark(color: accent).padding(10)
                }
            }
            .frame(width: 48, height: 48)
            Text(title).font(AppFont.serif(30)).foregroundStyle(accent)
            Text(line).font(AppFont.sans(16)).foregroundStyle(t.cream.opacity(0.85)).lineSpacing(5)
                .multilineTextAlignment(.leading)
            HStack {
                Spacer()
                Text("ادخل ←").font(AppFont.sans(15, .bold)).foregroundStyle(Palette.night)
                    .padding(.horizontal, 16).frame(height: 40)
                    .background(accent, in: Capsule())
            }
            .padding(.top, 8)
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
        .background(fill, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(accent.opacity(0.5), lineWidth: 1.5))
        .contentShape(RoundedRectangle(cornerRadius: 22))
    }
}
