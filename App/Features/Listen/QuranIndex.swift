import Foundation

/// Which ayah a quote between ﴿ ﴾ inside an explanation is, so the player recites it instead of the phone's voice
/// reading the Quran (owner 2026-11-27: «تكون القراءة صحيحة»). `Resources/Quran/quran-plain.json`: every ayah without
/// diacritics, alef / ya / ta marbuta unified — only to find a quote, never shown.
enum QuranIndex {
    private struct File: Decodable { let surahs: [[String]] }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var loaded: [[String]]?

    private static var surahs: [[String]] {
        lock.lock()
        defer { lock.unlock() }
        if let s = loaded { return s }
        guard let url = Bundle.main.url(forResource: "quran-plain", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let f = try? JSONDecoder().decode(File.self, from: data) else { return [] }
        loaded = f.surahs
        return f.surahs
    }

    /// The ayah (or the few ayat) a quote comes from; nil when it cannot be told — then the quote is not read.
    static func find(_ quote: String) -> (surah: Int, from: Int, to: Int)? {
        let words = normalize(quote).split(separator: " ").map(String.init)
        guard words.count >= 2 else { return nil }
        let whole = words.joined(separator: " ")
        let head = words.prefix(4).joined(separator: " ")
        let tail = words.suffix(4).joined(separator: " ")
        let all = surahs
        for (si, ayat) in all.enumerated() {
            for (ai, text) in ayat.enumerated() where text.contains(head) {
                if text.contains(whole) { return (si + 1, ai + 1, ai + 1) }
                // a quote over several ayat: its end within the next few
                for bi in (ai + 1)..<min(ayat.count, ai + 10) where ayat[bi].contains(tail) {
                    return (si + 1, ai + 1, bi + 1)
                }
            }
        }
        return nil
    }

    /// The same rule as the file's (made from the platform's data/quran.json).
    static func normalize(_ s: String) -> String {
        var out = String.UnicodeScalarView()
        for u in s.unicodeScalars {
            let v = u.value
            if (0x0610...0x061A).contains(v) || (0x064B...0x065F).contains(v) || v == 0x0670
                || (0x06D6...0x06ED).contains(v) || v == 0x0640 { continue }
            switch v {
            case 0x0623, 0x0625, 0x0622, 0x0671: out.append(Unicode.Scalar(0x0627)!)   // أ إ آ ٱ → ا
            case 0x0649: out.append(Unicode.Scalar(0x064A)!)                         // ى → ي
            case 0x0629: out.append(Unicode.Scalar(0x0647)!)                         // ة → ه
            case 0x0624: out.append(Unicode.Scalar(0x0648)!)                         // ؤ → و
            case 0x0626: out.append(Unicode.Scalar(0x064A)!)                         // ئ → ي
            case 0x0621...0x064A: out.append(u)
            default: out.append(" ")
            }
        }
        return String(out).split(separator: " ").joined(separator: " ")
    }
}
