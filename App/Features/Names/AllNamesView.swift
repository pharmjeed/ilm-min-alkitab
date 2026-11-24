import SwiftUI

/// /names — app/names/page.tsx + components/names/NamesExplorer.tsx (filters, sort, search inside the list).
/// With «الفئة» in the pack (owner 2026-11-24) the page shows the main categories as on alhosna.net; typing a search
/// (or choosing «مفرد» / «مركّب») shows the matching names as one list.
struct AllNamesView: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var nav: AppNav
    private let repo = NamesRepo.shared

    private enum Filter: String, CaseIterable { case all, single, compound }
    private enum Sort: String { case order, positions }

    @State private var q: String
    @State private var filter: Filter = .all
    @State private var sort: Sort = .order

    init(initialQuery: String = "") {
        _q = State(initialValue: initialQuery)
    }

    private var visible: [NameCard] {
        let qn = Arabic.normalize(q)
        var list = repo.names
        switch filter {
        case .single: list = list.filter { !$0.compound }
        case .compound: list = list.filter { $0.compound }
        case .all: break
        }
        if !qn.isEmpty {
            list = list.filter {
                Arabic.normalize($0.name).contains(qn) || Arabic.normalize($0.excerpt).contains(qn) || String($0.id) == qn
            }
        }
        if sort == .positions {
            list.sort { $0.positions != $1.positions ? $0.positions > $1.positions : $0.id < $1.id }
        }
        return list
    }

    /// The categories instead of the flat list: the pack has them and nothing narrows the list.
    private var byCategory: Bool {
        NameCategories.available(repo.names) && Arabic.normalize(q).isEmpty && filter == .all && sort == .order
    }

    var body: some View {
        let t = Theme(scheme)
        let shown = visible
        let groups = byCategory ? NameCategories.groups(repo.names) : []
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("كل الأسماء").font(AppFont.serif(30)).foregroundStyle(t.cream)
                (Text("\(repo.names.count)").foregroundColor(t.gold)
                    + Text(" صيغة بالترتيب المعتمد · ")
                    + Text(Num.fmt(repo.index?.stats.positions ?? 0)).foregroundColor(t.gold)
                    + Text(" موضعًا في القرآن"))
                    .font(AppFont.sans(16)).foregroundStyle(t.muted)
                    .padding(.top, 4)

                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(Filter.allCases, id: \.self) { f in
                        let on = filter == f
                        Button { filter = f } label: {
                            Text(label(f)).font(AppFont.sans(14))
                                .foregroundStyle(on ? t.bg : t.muted)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(on ? t.gold : Color.clear, in: Capsule())
                                .overlay(Capsule().stroke(on ? t.gold : t.line, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    Button { nav.tab = 1 } label: {
                        Text("♡ مفضلتي").font(AppFont.sans(14)).foregroundStyle(t.gold)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .overlay(Capsule().stroke(t.gold.opacity(0.5), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 24)

                HStack(spacing: 8) {
                    Text("الفرز:").font(AppFont.sans(14)).foregroundStyle(t.muted)
                    Menu {
                        Button("الترتيب المعتمد") { sort = .order }
                        Button("الأكثر مواضع") { sort = .positions }
                    } label: {
                        HStack(spacing: 6) {
                            Text(sort == .order ? "الترتيب المعتمد" : "الأكثر مواضع")
                            Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
                        }
                        .font(AppFont.sans(14)).foregroundStyle(t.cream)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(t.surface, in: Capsule())
                        .overlay(Capsule().stroke(t.line, lineWidth: 1))
                    }
                }
                .padding(.top, 12)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(t.muted)
                    TextField("", text: $q, prompt: Text("بحث داخل القائمة (اسم أو معنى أو رقم)…").foregroundColor(t.muted))
                        .font(AppFont.sans(15)).foregroundStyle(t.cream)
                        .submitLabel(.search)
                    if !q.isEmpty {
                        Button { q = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(t.muted) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16).frame(minHeight: 44)
                .background(t.surface, in: Capsule())
                .overlay(Capsule().stroke(t.line, lineWidth: 1))
                .padding(.top, 12)

                if !groups.isEmpty {
                    (Text("\(groups.count)").foregroundColor(t.gold) + Text(" تصنيفات — اختر تصنيفًا تظهر أسماؤه:"))
                        .font(AppFont.sans(14)).foregroundStyle(t.muted)
                        .padding(.top, 12)
                    LazyVStack(spacing: 12) {
                        ForEach(Array(groups.enumerated()), id: \.element.id) { i, g in
                            NamesLink(.nameCategory(g.title)) { NameCategoryCard(group: g, number: i + 1) }
                        }
                    }
                    .padding(.top, 16)
                } else {
                (Text("\(shown.count)").foregroundColor(t.gold) + Text(" من \(repo.names.count) صيغة"))
                    .font(AppFont.sans(14)).foregroundStyle(t.muted)
                    .padding(.top, 12)

                if shown.isEmpty {
                    Text("لا نتائج مطابقة.")
                        .font(AppFont.sans(16)).foregroundStyle(t.muted)
                        .frame(maxWidth: .infinity)
                        .siteCard(t, radius: 12, padding: 24)
                        .padding(.top, 24)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(shown) { n in
                            NamesLink(.name(n.id)) { NameCardView(card: n) }
                        }
                    }
                    .padding(.top, 16)
                }
                }
            }
            .multilineTextAlignment(.leading)
            .padding(16).padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.immediately)
        .namesScreen("كل الأسماء", t)
    }

    private func label(_ f: Filter) -> String {
        switch f {
        case .all: return "الكل"
        case .single: return "مفرد"
        case .compound: return "مركّب"
        }
    }
}

/// components/names/NameCard.tsx — number in a gold circle, name, first lines, badges.
struct NameCardView: View {
    @Environment(\.colorScheme) private var scheme
    let card: NameCard

    var body: some View {
        let t = Theme(scheme)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Text("\(card.id)").font(AppFont.sans(14)).foregroundStyle(t.gold)
                    .frame(width: 40, height: 40)
                    .overlay(Circle().stroke(t.gold.opacity(0.6), lineWidth: 1))
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.name).font(AppFont.serif(21)).foregroundStyle(t.cream)
                    if !card.excerpt.isEmpty {
                        Text(card.excerpt).font(AppFont.sans(14)).foregroundStyle(t.muted).lineSpacing(6).lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 6) {
                Badge(text: Arabic.positionsBadge(card.positions))
                Badge(text: Arabic.surahsBadge(card.surahs))
                if card.compound { Badge(text: "مركّب", emerald: true) }
            }
        }
        .multilineTextAlignment(.leading)
        .siteCard(t, radius: 12)
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct Badge: View {
    @Environment(\.colorScheme) private var scheme
    let text: String
    var emerald = false
    var body: some View {
        let t = Theme(scheme)
        Text(text).font(AppFont.sans(12)).foregroundStyle(emerald ? t.cream : t.muted)
            .padding(.horizontal, 10).padding(.vertical, 2)
            .background(emerald ? Palette.emerald.opacity(0.2) : Color.clear, in: Capsule())
            .overlay(Capsule().stroke(emerald ? Palette.emerald.opacity(0.6) : t.line, lineWidth: 1))
    }
}
