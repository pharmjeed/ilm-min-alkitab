import SwiftUI
import UIKit

/// The platform the app mirrors (share links point at the same pages on the website).
enum Site {
    static let base = URL(string: "https://asma-platform-nine.vercel.app")!
    static func url(_ path: String) -> URL {
        URL(string: path, relativeTo: base)?.absoluteURL ?? base
    }
    static func nameURL(_ id: Int) -> URL { url("/names/\(id)") }
}

// MARK: - Surfaces and buttons (the site's rounded-2xl border bg-surface cards, btn-primary, btn-secondary)

extension View {
    /// `rounded-xl/2xl border bg-surface` card.
    func siteCard(_ t: Theme, radius: CGFloat = 16, border: Color? = nil, fill: Color? = nil, padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill ?? t.surface, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(border ?? t.line, lineWidth: 1))
    }

    /// Screens of the names section share the site's background and an inline title.
    func namesScreen(_ title: String, _ t: Theme) -> some View {
        self
            .background(t.bg.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(t.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct PrimaryPill: ButtonStyle {
    var compact = false
    @Environment(\.colorScheme) private var scheme
    func makeBody(configuration: Configuration) -> some View {
        let t = Theme(scheme)
        configuration.label
            .font(AppFont.sans(compact ? 15 : 16, .medium))
            .foregroundStyle(t.bg)
            .padding(.horizontal, compact ? 14 : 20)
            .frame(minHeight: compact ? 40 : 46)
            .background(t.gold, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct SecondaryPill: ButtonStyle {
    var compact = false
    @Environment(\.colorScheme) private var scheme
    func makeBody(configuration: Configuration) -> some View {
        let t = Theme(scheme)
        configuration.label
            .font(AppFont.sans(compact ? 15 : 16, .medium))
            .foregroundStyle(t.cream)
            .padding(.horizontal, compact ? 14 : 20)
            .frame(minHeight: compact ? 40 : 46)
            .background(configuration.isPressed ? t.surface2 : Color.clear, in: Capsule())
            .overlay(Capsule().stroke(t.line, lineWidth: 1))
    }
}

/// Small bordered pill used by the card footers (مفضلة · نسخ · مشاركة · داخل صفحة الاسم).
struct ActionPill<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    let label: Content
    var on = false
    init(on: Bool = false, @ViewBuilder label: () -> Content) { self.on = on; self.label = label() }
    var body: some View {
        let t = Theme(scheme)
        label
            .font(AppFont.sans(14))
            .foregroundStyle(on ? t.gold : t.muted)
            .padding(.horizontal, 12)
            .frame(minHeight: 40)
            .background(on ? t.gold.opacity(0.15) : Color.clear, in: Capsule())
            .overlay(Capsule().stroke(on ? t.gold : t.line, lineWidth: 1))
    }
}

/// Gold-outlined chip that links somewhere (`rounded-full border border-gold/45`).
struct GoldChip: View {
    @Environment(\.colorScheme) private var scheme
    let text: String
    var body: some View {
        let t = Theme(scheme)
        Text(text)
            .font(AppFont.sans(14))
            .foregroundStyle(t.cream)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .overlay(Capsule().stroke(t.gold.opacity(0.45), lineWidth: 1))
            .contentShape(Capsule())
    }
}

// MARK: - Flow layout (flex-wrap)

struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineH: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(ProposedViewSize(width: maxW.isFinite ? maxW : nil, height: nil))
            if x > 0 && x + s.width > maxW { y += lineH + lineSpacing; x = 0; lineH = 0 }
            x += s.width + spacing
            lineH = max(lineH, s.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: maxW.isFinite ? maxW : widest, height: y + lineH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            if x > bounds.minX && x + s.width > bounds.maxX { y += lineH + lineSpacing; x = bounds.minX; lineH = 0 }
            v.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(width: s.width, height: s.height))
            x += s.width + spacing
            lineH = max(lineH, s.height)
        }
    }
}

// MARK: - Text

/// components/names/NamePageContent.tsx TextBlock: pre-line text, or «لا يوجد نص لهذا القسم.».
struct TextBlockView: View {
    @Environment(\.colorScheme) private var scheme
    let text: String?
    var size: CGFloat = 17
    var empty = "لا يوجد نص لهذا القسم."
    var body: some View {
        let t = Theme(scheme)
        let s = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty {
            Text(empty).font(AppFont.sans(size)).foregroundStyle(t.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(Arabic.rich(text ?? "", size: size))
                .font(AppFont.sans(size))
                .foregroundStyle(t.cream.opacity(0.95))
                .lineSpacing(9)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }
}

/// components/verses/AyahText.tsx: the verse exactly as stored, in ﴿ ﴾, Amiri, the name in gold; optional reference.
struct AyahTextView: View {
    @Environment(\.colorScheme) private var scheme
    let text: String
    var terms: [String] = []
    var size: CGFloat = 24
    var color: Color? = nil
    var reference: String? = nil
    var referenceSize: CGFloat = 14
    var referenceColor: Color? = nil

    var body: some View {
        let t = Theme(scheme)
        let marked = Arabic.highlighted(text, terms: terms, mark: t.gold)
        var all = AttributedString("﴿") + marked + AttributedString("﴾")
        all.font = AppFont.amiri(size)
        var line = Text(all)
        if let reference {
            line = line + Text("  " + reference).font(AppFont.sans(referenceSize)).foregroundColor(referenceColor ?? t.gold)
        }
        return line
            .foregroundStyle(color ?? t.cream)
            .lineSpacing(size * 0.55)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
    }
}

// MARK: - Feel helpers

/// components/feel/InnerMark.tsx: «صريح» filled gold, «مشترك» gold outline.
struct InnerMarkView: View {
    @Environment(\.colorScheme) private var scheme
    let level: String?
    var body: some View {
        let t = Theme(scheme)
        if level == "صريح" || level == "مشترك" {
            let explicit = level == "صريح"
            Text(level ?? "")
                .font(AppFont.sans(11.5, .medium))
                .foregroundStyle(t.gold)
                .padding(.horizontal, 8).padding(.vertical, 1)
                .background(explicit ? t.gold.opacity(0.15) : Color.clear, in: Capsule())
                .overlay(Capsule().stroke(t.gold.opacity(explicit ? 0.25 : 0.6), lineWidth: 1))
                .fixedSize()
        }
    }
}

/// components/feel/SituationItem.tsx — one situation in a list.
struct SituationRowView: View {
    @Environment(\.colorScheme) private var scheme
    let situation: Situation
    var mark: String? = nil
    var doorLabel: String? = nil
    var body: some View {
        let t = Theme(scheme)
        HStack(alignment: .center, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                if let mark { InnerMarkView(level: mark).padding(.top, 2) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(situation.situation.isEmpty ? situation.label : situation.situation)
                        .font(AppFont.sans(16)).foregroundStyle(t.cream)
                    if !situation.situation.isEmpty {
                        Text(situation.label).font(AppFont.sans(12.5)).foregroundStyle(t.muted)
                    }
                    if let doorLabel {
                        Text(doorLabel).font(AppFont.sans(11.5)).foregroundStyle(t.muted.opacity(0.8))
                    }
                }
                .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 4)
            Text("\(Arabic.namesCount(situation.names.count)) ←")
                .font(AppFont.sans(12.5)).foregroundStyle(t.gold).fixedSize()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.line, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct Crumb {
    let label: String
    let dest: HomeDestination
    init(_ label: String, _ route: NamesRoute) { self.label = label; self.dest = .n(route) }
    init(_ label: String, _ route: SunanRoute) { self.label = label; self.dest = .s(route) }
    init(_ label: String, dest: HomeDestination) { self.label = label; self.dest = dest }
}

/// components/feel/FeelCrumbs.tsx — the path when it is deeper than one step (the native back button replaces «رجوع»).
struct CrumbsView: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var nav: AppNav
    let trail: [Crumb]
    let current: String
    var body: some View {
        let t = Theme(scheme)
        if trail.count > 1 {
            FlowLayout(spacing: 6, lineSpacing: 4) {
                ForEach(Array(trail.enumerated()), id: \.offset) { _, c in
                    Button { nav.open(dest: c.dest) } label: {
                        Text(c.label).underline(color: t.gold.opacity(0.4)).foregroundStyle(t.gold.opacity(0.9))
                    }
                    .buttonStyle(.plain)
                    Text("›").foregroundStyle(t.muted)
                }
                Text(current).foregroundStyle(t.cream.opacity(0.8))
            }
            .font(AppFont.sans(14))
        }
    }
}

// MARK: - Share / copy / save

/// The website's share buttons (Web Share with title, text and the page URL). With a `card` (owner 2026-11-25) it
/// opens the designed card with the whole text first (ShareCard.swift).
struct SharePill: View {
    let title: String
    let text: String
    let url: URL
    var card: ShareCard? = nil
    /// The CI route that opens this card for a screenshot (ci/routes.txt).
    var ci = "sitemshare"
    @State private var showCard = false
    var body: some View {
        if let card {
            Button { showCard = true } label: {
                ActionPill { Label { Text("مشاركة") } icon: { Image(systemName: "square.and.arrow.up") } }
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showCard) {
                ShareCardSheet(card: card, title: title, text: text, url: url)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .onAppear {
                // CI screenshot of the card page (ci/routes.txt `sitemshare`, `namewshare`, `namevshare`)
                if Route.isCI, Route.arg == ci, !ShareCardCI.shown { ShareCardCI.shown = true; showCard = true }
            }
        } else {
            ShareLink(item: url, subject: Text(title), message: Text(text)) {
                ActionPill { Label { Text("مشاركة") } icon: { Image(systemName: "square.and.arrow.up") } }
            }
            .buttonStyle(.plain)
        }
    }
}

enum ShareCardCI { static var shown = false }

/// The website's copy buttons: the text with `{url}` replaced, then «تم النسخ» for a moment.
struct CopyPill: View {
    let label: String
    let text: String
    @State private var done = false
    var body: some View {
        Button {
            UIPasteboard.general.string = text
            done = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { done = false }
        } label: {
            ActionPill { Label { Text(done ? "تم النسخ" : label) } icon: { Image(systemName: "doc.on.doc") } }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Loading a name's detail

/// Loads a name's chunk off the main thread, then shows the content («جارٍ التحميل…» meanwhile).
struct NameDetailLoader<Inner: View>: View {
    @Environment(\.colorScheme) private var scheme
    let id: Int
    let content: (NameDetail) -> Inner
    @State private var detail: NameDetail?
    @State private var failed = false

    init(id: Int, @ViewBuilder content: @escaping (NameDetail) -> Inner) {
        self.id = id
        self.content = content
    }

    var body: some View {
        let t = Theme(scheme)
        Group {
            if let detail {
                content(detail)
            } else if failed {
                Text("تعذّر تحميل هذا الاسم.").font(AppFont.sans(16)).foregroundStyle(t.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView { Text("جارٍ التحميل…").font(AppFont.sans(15)).foregroundStyle(t.muted) }
                    .tint(t.gold)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: id) {
            if detail?.id == id { return }
            do { detail = try await NameDetails.shared.detail(id) } catch { failed = true }
        }
    }
}
