import SwiftUI
import UIKit

/// What «مشاركة» shares (owner 2026-11-25: «عند الضغط على مشاركة اريد ان يظهر تصميم وبه العبارة كاملة»): a designed
/// card with the WHOLE text — the verse between ﴿ ﴾ or the hadith between « » in Amiri, verbatim — its source and
/// the app's mark, rendered as an image and shared with the page's link.
struct ShareCard {
    /// The small gold line on top (the name, or the state of a sunnah).
    var kicker: String
    /// The large line (a name, or «السبب ← النتيجة»).
    var headline: AttributedString? = nil
    var headlineIsName = false
    /// «جملة الربط» of a situation page (the precise state, then the bridge sentence) — above the scripture, as on the card.
    var bridge: Note? = nil
    /// The whole scripture text as the page shows it.
    var scripture: String? = nil
    var source: String? = nil
    /// The card's explanations under the text (owner 2026-11-25: «اريد معه الكلام») — «القصة»، «سبب ذكر الاسم»…
    var notes: [Note] = []

    /// One explanation: an optional small gold title over its text (`**bold**` as on the page).
    struct Note {
        var title: String?
        var text: String
    }

    /// The non-empty explanations of a card, in its order.
    static func notes(_ pairs: [(String?, String?)]) -> [Note] {
        pairs.compactMap { title, text in
            guard let x = text?.trimmingCharacters(in: .whitespacesAndNewlines), !x.isEmpty else { return nil }
            return Note(title: title, text: x)
        }
    }

    /// The bridge box of a situation page, when it has either part.
    static func bridge(situation: String?, note: String?) -> Note? {
        let s = situation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let n = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if s.isEmpty && n.isEmpty { return nil }
        return Note(title: s.isEmpty ? nil : s, text: n)
    }

    /// A hadith between « », unless its text already opens with one (many do).
    static func quoted(_ s: String) -> String {
        let x = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return x.hasPrefix("«") ? x : "«\(x)»"
    }
}

/// The card itself, always in the brand's dark look (night, gold, cream) and 360 points wide.
struct ShareCardView: View {
    let card: ShareCard
    static let width: CGFloat = 360
    static let gold = Color(hex: 0xD4A449)
    static let cream = Color(hex: 0xF7ECD6)

    var body: some View {
        let gold = Self.gold, cream = Self.cream
        VStack(alignment: .leading, spacing: 0) {
            Text(card.kicker).font(AppFont.sans(14, .medium)).foregroundStyle(gold)
                .fixedSize(horizontal: false, vertical: true)
            if let h = card.headline {
                Text(h).font(AppFont.serif(card.headlineIsName ? 40 : 23)).foregroundStyle(cream).lineSpacing(8)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
            }
            if let b = card.bridge {
                VStack(alignment: .leading, spacing: 4) {
                    if let s = b.title {
                        Text(s).font(AppFont.sans(15, .bold)).foregroundStyle(gold).lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !b.text.isEmpty {
                        Text(Arabic.rich(b.text, size: 15)).font(AppFont.sans(15)).foregroundStyle(cream.opacity(0.95))
                            .lineSpacing(7).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(gold.opacity(0.07))
                .overlay(alignment: .leading) { Rectangle().fill(gold.opacity(0.6)).frame(width: 2) }
                .padding(.top, 16)
            }
            if let s = card.scripture, !s.isEmpty {
                Text(s).font(AppFont.amiri(20)).foregroundStyle(cream).lineSpacing(11)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 16)
            }
            if let src = card.source, !src.isEmpty {
                Text(src).font(AppFont.sans(12)).foregroundStyle(cream.opacity(0.62)).lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
            }
            ForEach(Array(card.notes.enumerated()), id: \.offset) { _, n in
                VStack(alignment: .leading, spacing: 4) {
                    if let title = n.title {
                        Text(title).font(AppFont.sans(14, .bold)).foregroundStyle(gold)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(Arabic.rich(n.text, size: 15)).font(AppFont.sans(15)).foregroundStyle(cream.opacity(0.9))
                        .lineSpacing(7).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 18)
            }
            Rectangle().fill(gold.opacity(0.3)).frame(height: 1).padding(.top, 22)
            HStack(spacing: 10) {
                Text("علم من الكتاب").font(AppFont.serif(19)).foregroundStyle(cream)
                Spacer(minLength: 0)
                BrandMark(color: gold).frame(width: 26, height: 26)
            }
            .padding(.top, 14)
        }
        .multilineTextAlignment(.leading)
        .padding(26)
        .frame(width: Self.width, alignment: .leading)
        .background(Palette.night)
    }
}

@MainActor
enum ShareCardRenderer {
    /// The card as a picture (3× — sharp on any phone), laid out right to left.
    static func image(_ card: ShareCard) -> UIImage? {
        let r = ImageRenderer(content: ShareCardView(card: card)
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.colorScheme, .dark))
        r.scale = 3
        r.proposedSize = ProposedViewSize(width: ShareCardView.width, height: nil)
        return r.uiImage
    }
}

/// The page «مشاركة» opens: the card as it will be sent, «مشاركة الصورة» (with the link as the message) and
/// «مشاركة الرابط فقط» (what the button did before).
struct ShareCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    let card: ShareCard
    let title: String
    let text: String
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        let t = Theme(scheme)
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let image {
                        Image(uiImage: image).resizable().scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(t.line, lineWidth: 1))
                        ShareLink(item: Image(uiImage: image), subject: Text(title), message: Text(url.absoluteString),
                                  preview: SharePreview(title, image: Image(uiImage: image))) {
                            Label { Text("مشاركة الصورة") } icon: { Image(systemName: "square.and.arrow.up") }
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryPill())
                    } else {
                        ProgressView().frame(height: 240)
                    }
                    ShareLink(item: url, subject: Text(title), message: Text(text)) {
                        Text("مشاركة الرابط فقط").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryPill())
                }
                .padding(20)
            }
            .background(t.bg.ignoresSafeArea())
            .navigationTitle("مشاركة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إغلاق") { dismiss() }.foregroundStyle(t.gold)
                }
            }
        }
        .task { image = ShareCardRenderer.image(card) }
    }
}
