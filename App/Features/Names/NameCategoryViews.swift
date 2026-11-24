import SwiftUI

/// «كل الأسماء» by «الفئة» — the classification of alhosna.net (owner 2026-11-24): eight main categories in the site's
/// order; «أسماء الكفاية» and «توابع الأسماء الحسنى» hold sub-categories; each category's names follow «ترتيب الفئة».
enum NameCategories {
    static let kifaya = "أسماء الكفاية"
    static let tawabi = "توابع الأسماء الحسنى"

    /// The main category of a «الفئة» label.
    static func main(_ label: String) -> String {
        if label.hasPrefix(kifaya) { return kifaya }
        if label.hasPrefix("فئة ") { return tawabi }
        return label
    }

    /// The sub-category heading inside its main category (nil when the main category has none).
    static func sub(_ label: String) -> String? {
        if label.hasPrefix(kifaya) {
            if let r = label.range(of: "— ") { return String(label[r.upperBound...]) }
            return nil
        }
        if label.hasPrefix("فئة ") { return label }
        return nil
    }

    struct Sub: Identifiable {
        let title: String?
        var names: [NameCard]
        var id: String { title ?? "" }
    }

    struct Group: Identifiable {
        let title: String
        var subs: [Sub]
        var id: String { title }
        var count: Int { subs.reduce(0) { $0 + $1.names.count } }
        var allNames: [NameCard] { subs.flatMap(\.names) }
    }

    /// Whether the pack carries the classification (every name has a category).
    static func available(_ names: [NameCard]) -> Bool {
        !names.isEmpty && names.allSatisfy { $0.category != nil }
    }

    /// Groups in the classification's order; inside each, its sub-categories and names in «ترتيب الفئة».
    static func groups(_ names: [NameCard]) -> [Group] {
        let ordered = names.sorted { a, b in
            let x = a.categoryOrder ?? Int.max, y = b.categoryOrder ?? Int.max
            return x != y ? x < y : a.id < b.id
        }
        var out: [Group] = []
        for n in ordered {
            guard let label = n.category else { continue }
            let m = main(label), s = sub(label)
            var gi = out.firstIndex { $0.title == m }
            if gi == nil { out.append(Group(title: m, subs: [])); gi = out.count - 1 }
            if let si = out[gi!].subs.firstIndex(where: { $0.title == s }) {
                out[gi!].subs[si].names.append(n)
            } else {
                out[gi!].subs.append(Sub(title: s, names: [n]))
            }
        }
        return out
    }
}

/// One main category on «كل الأسماء»: its title, a glimpse of its first names, and the count.
struct NameCategoryCard: View {
    @Environment(\.colorScheme) private var scheme
    let group: NameCategories.Group
    let number: Int

    var body: some View {
        let t = Theme(scheme)
        let first = group.allNames.prefix(4).map(\.name).joined(separator: " · ") + (group.count > 4 ? " …" : "")
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Text("\(number)").font(AppFont.sans(14)).foregroundStyle(t.gold)
                    .frame(width: 36, height: 36)
                    .overlay(Circle().stroke(t.gold.opacity(0.6), lineWidth: 1))
                Text(group.title).font(AppFont.serif(22)).foregroundStyle(t.cream)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            Text(first).font(AppFont.sans(14)).foregroundStyle(t.muted).lineSpacing(6).lineLimit(2)
            if group.subs.count > 1 {
                Text(group.subs.compactMap(\.title).joined(separator: " · "))
                    .font(AppFont.sans(13)).foregroundStyle(t.gold.opacity(0.85)).lineSpacing(5)
            }
            Rectangle().fill(t.line).frame(height: 1)
            // owner 2026-11-24: the card's count removed
            HStack {
                Spacer(minLength: 8)
                Text("افتح ←")
            }
            .font(AppFont.sans(14)).foregroundStyle(t.gold)
        }
        .multilineTextAlignment(.leading)
        .siteCard(t, radius: 16)
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}

extension NameCategories {
    static let forms = Arabic.CountForms(one: "اسم واحد", two: "اسمان", few: "أسماء", many: "اسمًا")
}

/// One main category: its names in the classification's order, under their sub-category headings.
struct NameCategoryView: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var nav: AppNav
    let title: String
    private let repo = NamesRepo.shared

    var body: some View {
        let t = Theme(scheme)
        let groups = NameCategories.groups(repo.names)
        let k = groups.firstIndex { $0.title == title }
        ScrollView {
            if let k {
                let g = groups[k]
                let prev = k > 0 ? groups[k - 1] : nil
                let next = k + 1 < groups.count ? groups[k + 1] : nil
                VStack(alignment: .leading, spacing: 0) {
                    CrumbsView(trail: [Crumb("كل الأسماء", .allNames())], current: g.title)
                        .padding(.bottom, 16)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("كل الأسماء").font(AppFont.sans(14)).foregroundStyle(t.gold)
                        Text(g.title).font(AppFont.serif(30)).foregroundStyle(t.cream).lineSpacing(4)
                        Text(Arabic.count(g.count, NameCategories.forms) + (g.subs.count > 1 ? " في \(Arabic.count(g.subs.count, NameCategories.subs))" : ""))
                            .font(AppFont.sans(16)).foregroundStyle(t.muted)
                            .padding(.top, 4)
                    }
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .siteCard(t, radius: 16, padding: 20)

                    ForEach(g.subs) { s in
                        if let st = s.title {
                            HStack(alignment: .lastTextBaseline) {
                                Text(st).font(AppFont.serif(22)).foregroundStyle(t.cream)
                                Spacer(minLength: 8)
                                Text(Arabic.count(s.names.count, NameCategories.forms)).font(AppFont.sans(13)).foregroundStyle(t.gold)
                            }
                            .padding(.top, 28)
                        }
                        LazyVStack(spacing: 12) {
                            ForEach(s.names) { n in
                                NamesLink(.name(n.id)) { NameCardView(card: n) }
                            }
                        }
                        .padding(.top, s.title == nil ? 16 : 12)
                    }

                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        if let prev {
                            CategoryBackLink(text: "→ \(prev.title)") { nav.replaceLastNames(.nameCategory(prev.title)) }
                        }
                        CategoryBackLink(text: "كل الأسماء") { nav.open(.allNames()) }
                        if let next {
                            CategoryBackLink(text: "\(next.title) ←") { nav.replaceLastNames(.nameCategory(next.title)) }
                        }
                    }
                    .padding(.top, 32)
                }
                .padding(16).padding(.bottom, 24)
            }
        }
        .namesScreen("كل الأسماء", t)
    }
}

extension NameCategories {
    static let subs = Arabic.CountForms(one: "فئة واحدة", two: "فئتين", few: "فئات", many: "فئة")
}

private struct CategoryBackLink: View {
    @Environment(\.colorScheme) private var scheme
    let text: String
    let action: () -> Void
    var body: some View {
        let t = Theme(scheme)
        Button(action: action) {
            Text(text).font(AppFont.sans(14)).foregroundStyle(t.gold)
                .padding(.horizontal, 14).frame(minHeight: 40)
                .overlay(Capsule().stroke(t.gold.opacity(0.45), lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
