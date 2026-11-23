import SwiftUI

// Building blocks of the sunan pages (ports of components/sunan/* on the website).

extension Theme {
    /// The site's --error (#b4443c): the «ما تتجنّبه» edge and «عاقبته».
    var error: Color { Color(hex: 0xB4443C) }
}

extension View {
    /// `rounded-2xl border bg-surface` header; `avoid` adds the site's `border-r-2 border-r-error/60` (the start edge).
    func sunanHeader(_ t: Theme, gold: Bool = false, avoid: Bool = false, padding: CGFloat = 20) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(t.surface)
            .overlay(alignment: .leading) {
                if avoid { Rectangle().fill(t.error.opacity(0.6)).frame(width: 2) }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(gold ? t.gold.opacity(0.4) : t.line, lineWidth: 1))
    }

    /// `rounded-xl border border-line bg-surface` list row.
    func sunanRow(_ t: Theme, border: Color? = nil, avoid: Bool = false, fill: Color? = nil,
                  h: CGFloat = 16, v: CGFloat = 12, radius: CGFloat = 12) -> some View {
        self
            .padding(.horizontal, h).padding(.vertical, v)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill ?? t.surface)
            .overlay(alignment: .leading) {
                if avoid { Rectangle().fill(t.error.opacity(0.6)).frame(width: 2) }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(border ?? t.line, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: radius))
    }
}

/// Loads a value off the main thread, then shows the content («جارٍ التحميل…» meanwhile).
struct SunanLoader<Value, Inner: View>: View {
    @Environment(\.colorScheme) private var scheme
    let key: String
    let load: () async throws -> Value
    let content: (Value) -> Inner
    @State private var value: Value?
    @State private var loadedKey: String?
    @State private var failed = false

    init(key: String, load: @escaping () async throws -> Value, @ViewBuilder content: @escaping (Value) -> Inner) {
        self.key = key
        self.load = load
        self.content = content
    }

    var body: some View {
        let t = Theme(scheme)
        Group {
            if let value, loadedKey == key {
                content(value)
            } else if failed {
                Text("تعذّر تحميل هذه الصفحة.").font(AppFont.sans(16)).foregroundStyle(t.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView { Text("جارٍ التحميل…").font(AppFont.sans(15)).foregroundStyle(t.muted) }
                    .tint(t.gold)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: key) {
            if loadedKey == key, value != nil { return }
            do {
                value = try await load()
                loadedKey = key
                failed = false
            } catch {
                failed = true
            }
        }
    }
}

/// StarBadge — «ابدأ بهذه».
struct StarBadge: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let t = Theme(scheme)
        Text("ابدأ بهذه")
            .font(AppFont.sans(12, .medium)).foregroundStyle(t.gold)
            .padding(.horizontal, 10).padding(.vertical, 2)
            .background(t.gold.opacity(0.1), in: Capsule())
            .overlay(Capsule().stroke(t.gold.opacity(0.6), lineWidth: 1))
            .fixedSize()
    }
}

/// «اجتهاد» badge.
struct IjtihadBadge: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let t = Theme(scheme)
        Text("اجتهاد")
            .font(AppFont.sans(11)).foregroundStyle(t.muted)
            .padding(.horizontal, 8).padding(.vertical, 2)
            .overlay(Capsule().stroke(t.line, lineWidth: 1))
            .fixedSize()
    }
}

/// RunsLegend — the two colours, explained once per page.
struct RunsLegend: View {
    @Environment(\.colorScheme) private var scheme
    var cause = "السبب"
    var result = "النتيجة"
    var size: CGFloat = 12
    var body: some View {
        let t = Theme(scheme)
        var a = AttributedString("بالذهبي: \(cause)")
        a.foregroundColor = t.gold
        var b = AttributedString("بالأخضر: \(result)")
        b.foregroundColor = t.result
        return Text(a + AttributedString(" · ") + b)
            .font(AppFont.sans(size)).foregroundStyle(t.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Bold section title (`font-display text-step-1/2`).
struct SunanHeading: View {
    @Environment(\.colorScheme) private var scheme
    let text: String
    var size: CGFloat = 22
    var color: Color? = nil
    var body: some View {
        let t = Theme(scheme)
        Text(text).font(AppFont.serif(size)).foregroundStyle(color ?? t.cream)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// «طريقة التطبيق» box (`border-r-2 border-gold/60 bg-gold/5`).
struct ApplyBox: View {
    @Environment(\.colorScheme) private var scheme
    let apply: SunnahApply
    /// The item page shows the «طريقة التطبيق» heading; the day rows do not.
    var titled = false
    var body: some View {
        let t = Theme(scheme)
        var line = AttributedString()
        if let label = SunanText.applyLabel(apply.k) {
            var l = AttributedString("\(label): ")
            l.foregroundColor = t.gold
            l.font = AppFont.sans(titled ? 16 : 14, .bold)
            line += l
        }
        line += AttributedString(apply.t)
        return VStack(alignment: .leading, spacing: 2) {
            if titled {
                Text("طريقة التطبيق").font(AppFont.sans(16, .bold)).foregroundStyle(t.gold)
            }
            Text(line).font(AppFont.sans(titled ? 16 : 14)).foregroundStyle(t.cream.opacity(0.95)).lineSpacing(titled ? 7 : 5)
        }
        .multilineTextAlignment(.leading)
        .padding(.horizontal, 12).padding(.vertical, titled ? 8 : 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.gold.opacity(0.05))
        .overlay(alignment: .leading) { Rectangle().fill(t.gold.opacity(0.6)).frame(width: 2) }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// SunanItemCard — one sunnah in a list: the easy line, its source, and how many say the same.
struct SunanItemCardView: View {
    @Environment(\.colorScheme) private var scheme
    let item: SunnahItem
    var n: Int? = nil
    var body: some View {
        let t = Theme(scheme)
        let similar = item.similar?.count ?? 0
        VStack(alignment: .leading, spacing: 8) {
            if item.isStar || item.isIjtihad || n != nil {
                HStack(spacing: 8) {
                    if let n { Text("\(n)").font(AppFont.sans(12)).foregroundStyle(t.muted) }
                    if item.isStar { StarBadge() }
                    if item.isIjtihad { IjtihadBadge() }
                }
            }
            Text(SunanText.easy(item.easy, t)).font(AppFont.sans(18)).lineSpacing(9)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(SunanText.sourceLine(item)).foregroundStyle(t.muted)
                Spacer(minLength: 0)
                if similar > 0 { Text("+\(similar) بمعناها").foregroundStyle(t.gold).fixedSize() }
            }
            .font(AppFont.sans(12))
        }
        .multilineTextAlignment(.leading)
        .sunanRow(t, border: item.isStar ? t.gold.opacity(0.45) : t.line, h: 16, v: 16)
    }
}

/// QuranItemText — each ayah verbatim in ﴿ ﴾ with its highlighted runs, then the reference.
struct QuranItemTextView: View {
    @Environment(\.colorScheme) private var scheme
    let quran: SunnahQuran
    var size: CGFloat = 24
    var body: some View {
        let t = Theme(scheme)
        let ayat = SunanText.quranAyat(quran.text, quran.hl)
        let surah = Surahs.name(quran.s)
        var all = AttributedString()
        for a in ayat {
            var open = AttributedString("﴿")
            open.font = AppFont.amiri(size)
            var verse = SunanText.attr(a.runs, t)
            verse.font = AppFont.amiri(size)
            var close = AttributedString("﴾")
            close.font = AppFont.amiri(size)
            all += open + verse + close
            if a.a > 0 && ayat.count > 1 {
                var n = AttributedString(" (\(a.a))")
                n.font = AppFont.sans(12)
                n.foregroundColor = t.muted
                all += n
            }
            var space = AttributedString(" ")
            space.font = AppFont.amiri(size)
            all += space
        }
        let range = quran.from == quran.to ? "\(quran.from)" : "\(quran.from)–\(quran.to)"
        var ref = AttributedString(" [\(surah.isEmpty ? "" : "\(surah): ")\(range)]")
        ref.font = AppFont.sans(14)
        ref.foregroundColor = t.gold
        all += ref
        return Text(all)
            .foregroundStyle(t.cream)
            .lineSpacing(size * 0.55)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
    }
}

/// HadithRuns — the full text «…» in Amiri, cause / result runs coloured (no second «» when the text has its own).
struct HadithRunsView: View {
    @Environment(\.colorScheme) private var scheme
    let segs: [SunanSeg]
    var body: some View {
        let t = Theme(scheme)
        let quoted = SunanText.plain(segs).trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("«")
        let inner = SunanText.attr(SunanText.segRuns(segs), t)
        let all = quoted ? inner : AttributedString("«") + inner + AttributedString("»")
        return Text(all)
            .font(AppFont.amiri(20))
            .foregroundStyle(t.cream)
            .lineSpacing(12)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
    }
}

/// The item page's <details> folds (التخريج، باب الحديث، روايات أخرى، لماذا هي اجتهاد؟).
struct SunanFold<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    let content: Content
    @State private var open: Bool

    init(_ title: String, open: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
        _open = State(initialValue: open)
    }

    var body: some View {
        let t = Theme(scheme)
        VStack(alignment: .leading, spacing: 8) {
            Button { withAnimation(.easeInOut(duration: 0.2)) { open.toggle() } } label: {
                HStack(spacing: 6) {
                    Text(title)
                    Text(open ? "▴" : "▾")
                }
                .font(AppFont.sans(14)).foregroundStyle(t.gold)
                .padding(.horizontal, 12).frame(minHeight: 40)
                .background(open ? t.gold.opacity(0.1) : Color.clear, in: Capsule())
                .overlay(Capsule().stroke(t.gold.opacity(0.45), lineWidth: 1))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            if open {
                content
                    .font(AppFont.sans(16)).foregroundStyle(t.cream.opacity(0.9)).lineSpacing(8)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, 12)
    }
}

/// `list-disc` bullets.
struct BulletList: View {
    let lines: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, l in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("•")
                    Text(l).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

/// `rounded-full border border-gold/30 bg-gold/5 text-gold/90` chip.
struct SunanChip: View {
    @Environment(\.colorScheme) private var scheme
    let text: String
    var size: CGFloat = 12
    var body: some View {
        let t = Theme(scheme)
        Text(text)
            .font(AppFont.sans(size)).foregroundStyle(t.gold.opacity(0.9))
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 12).padding(.vertical, size >= 14 ? 9 : 7)
            .background(t.gold.opacity(0.05), in: Capsule())
            .overlay(Capsule().stroke(t.gold.opacity(0.3), lineWidth: 1))
            .contentShape(Capsule())
    }
}

/// The bottom «→ بقية …» link (`rounded-xl border border-line bg-surface px-4 py-3 text-sm`).
struct SunanBackLink: View {
    @Environment(\.colorScheme) private var scheme
    let text: String
    let action: () -> Void
    var body: some View {
        let t = Theme(scheme)
        Button(action: action) {
            Text(text).font(AppFont.sans(14)).foregroundStyle(t.cream)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(t.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.line, lineWidth: 1))
                .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

/// SunanSearchForm — the field, then «ابحث» (stacked as on a phone-width page).
struct SunanSearchField: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var text: String
    let submit: () -> Void
    var body: some View {
        let t = Theme(scheme)
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("", text: $text, prompt: Text(SunanText.searchPrompt).foregroundColor(t.muted))
                    .font(AppFont.sans(16)).foregroundStyle(t.cream)
                    .submitLabel(.search)
                    .onSubmit(submit)
                    .onChange(of: text) { _, v in if v.count > 120 { text = String(v.prefix(120)) } }
                if !text.isEmpty {
                    Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(t.muted) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).frame(minHeight: 46)
            .background(t.bg.opacity(0.4), in: Capsule())
            .overlay(Capsule().stroke(t.line, lineWidth: 1))
            Button(action: submit) { Text("ابحث").frame(maxWidth: .infinity) }
                .buttonStyle(PrimaryPill())
        }
    }
}

extension View {
    /// Screens of the sunan section: the site's background and an inline title (same chrome as the names section).
    func sunanScreen(_ title: String, _ t: Theme) -> some View { namesScreen(title, t) }
}
