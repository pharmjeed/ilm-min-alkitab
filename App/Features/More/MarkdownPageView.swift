import SwiftUI

/// «عن المنصة» / «المنهجية»: the website's pages (names pack `pages`), as light markdown.
enum MorePage: Hashable {
    case about, methodology
    var title: String {
        switch self {
        case .about: return "عن المنصة"
        case .methodology: return "المنهجية"
        }
    }
}

struct MarkdownPageView: View {
    let page: MorePage
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        let pages = NamesRepo.shared.index?.pages
        let md = (page == .about ? pages?.about : pages?.methodology) ?? ""
        let blocks = LightMarkdown.blocks(md)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if blocks.isEmpty {
                    Text("لا يوجد نص لهذه الصفحة بعد.").font(AppFont.sans(16)).foregroundStyle(t.muted)
                }
                ForEach(Array(blocks.enumerated()), id: \.offset) { i, b in
                    LightMarkdownBlockView(block: b, first: i == 0)
                }
            }
            .padding(20)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .namesScreen(page.title, t)
    }
}

/// The markdown the platform's pages use (marked, gfm + breaks): `#`/`##`/`###` headings, `-`/`*` lists, `1.` lists,
/// `>` quotes, paragraphs with line breaks, and inline `**bold**` / links. A line that is an ayah alone (﴿…﴾) is
/// shown as the site's ayah: Amiri, gold, centred; ayahs inside a sentence are set in Amiri.
enum LightMarkdown {
    enum Block {
        case h2(String), h3(String), para(String), bullet(String), ordered(String, String), quote(String)
    }

    static let open = "\u{FD3F}"
    static let close = "\u{FD3E}"

    static func blocks(_ md: String) -> [Block] {
        var out: [Block] = []
        var para: [String] = []
        func flush() {
            if !para.isEmpty {
                out.append(.para(para.joined(separator: "\n")))
                para.removeAll()
            }
        }
        for raw in md.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { flush(); continue }
            if line.hasPrefix("### ") { flush(); out.append(.h3(String(line.dropFirst(4)))) }
            else if line.hasPrefix("## ") { flush(); out.append(.h2(String(line.dropFirst(3)))) }
            else if line.hasPrefix("# ") { flush(); out.append(.h2(String(line.dropFirst(2)))) }
            else if line.hasPrefix("- ") || line.hasPrefix("* ") { flush(); out.append(.bullet(String(line.dropFirst(2)))) }
            else if line.hasPrefix("> ") { flush(); out.append(.quote(String(line.dropFirst(2)))) }
            else if let o = ordered(line) { flush(); out.append(.ordered(o.0, o.1)) }
            else { para.append(line) }
        }
        flush()
        return out
    }

    private static func ordered(_ line: String) -> (String, String)? {
        guard let dot = line.firstIndex(of: "."), dot > line.startIndex else { return nil }
        let num = line[..<dot]
        guard num.count <= 3, num.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        let after = line[line.index(after: dot)...]
        guard after.hasPrefix(" ") else { return nil }
        return (String(num), String(after.dropFirst()))
    }

    static func strip(_ s: String) -> String { s.replacingOccurrences(of: "**", with: "") }

    static func isAyahLine(_ s: String) -> Bool {
        let x = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return x.hasPrefix(open) && x.hasSuffix(close)
            && x.components(separatedBy: open).count == 2 && x.components(separatedBy: close).count == 2
    }

    /// Inline markdown with the app's fonts: bold runs in Thmanyah Bold, links gold, ayah spans in Amiri.
    static func inline(_ s: String, size: CGFloat, t: Theme) -> AttributedString {
        let opts = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        var a = (try? AttributedString(markdown: s, options: opts)) ?? AttributedString(s)
        for run in a.runs {
            let strong = run.inlinePresentationIntent?.contains(.stronglyEmphasized) ?? false
            a[run.range].font = AppFont.sans(size, strong ? .bold : .regular)
            if run.link != nil { a[run.range].foregroundColor = t.gold }
        }
        var from = a.startIndex
        while from < a.endIndex,
              let o = a[from...].range(of: open),
              let c = a[o.upperBound...].range(of: close) {
            a[o.lowerBound..<c.upperBound].font = AppFont.amiri(size + 3)
            from = c.upperBound
        }
        return a
    }
}

struct LightMarkdownBlockView: View {
    let block: LightMarkdown.Block
    let first: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        switch block {
        case .h2(let s):
            Text(LightMarkdown.strip(s)).font(AppFont.serif(26)).foregroundStyle(t.cream)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, first ? 0 : 24)
        case .h3(let s):
            Text(LightMarkdown.strip(s)).font(AppFont.serif(20)).foregroundStyle(t.gold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, first ? 0 : 22)
        case .para(let s):
            if LightMarkdown.isAyahLine(s) {
                Text(s).font(AppFont.amiri(24)).foregroundStyle(t.gold)
                    .multilineTextAlignment(.center).lineSpacing(8)
                    .frame(maxWidth: .infinity)
                    .padding(.top, first ? 0 : 16)
                    .textSelection(.enabled)
            } else {
                Text(LightMarkdown.inline(s, size: 17, t: t))
                    .foregroundStyle(t.cream.opacity(0.92)).lineSpacing(9)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, first ? 0 : 12)
                    .textSelection(.enabled)
            }
        case .bullet(let s):
            item(t, marker: "•", s)
        case .ordered(let n, let s):
            item(t, marker: "\(n).", s)
        case .quote(let s):
            HStack(alignment: .top, spacing: 12) {
                Rectangle().fill(t.gold).frame(width: 3)
                Text(LightMarkdown.inline(s, size: 16, t: t)).foregroundStyle(t.muted).lineSpacing(8)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 12)
        }
    }

    private func item(_ t: Theme, marker: String, _ s: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(marker).font(AppFont.sans(17)).foregroundStyle(t.gold)
            Text(LightMarkdown.inline(s, size: 17, t: t))
                .foregroundStyle(t.cream.opacity(0.92)).lineSpacing(9)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 8)
    }
}
