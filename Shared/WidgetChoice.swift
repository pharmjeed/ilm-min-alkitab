import Foundation
import Security

/// What the home widget shows (owner 2026-11-26): «تلقائي» (the day's name and sunnah) or one of the reader's
/// collections of «محفوظاتي», chosen in «المزيد». The app writes it; the widget extension reads it. It travels in a
/// keychain item of the group both share (`keychain-access-groups`: TEAM.com.pharmjeed.ilmminalkitab.shared) — the
/// first group of each, so an item added without a group lands there and a search without one finds it.
struct WidgetChoice: Codable, Equatable {
    /// The collection's title, shown at the top of the widget.
    var title: String
    var items: [Item]

    /// One item of the collection, already described by the app (the widget has no sunan or situations data).
    struct Item: Codable, Hashable {
        /// "name" | "position" | "sunnah" | "text"
        var k: String
        /// name / position: the name's id
        var id: Int? = nil
        /// position: surah and ayah
        var s: Int? = nil
        var a: Int? = nil
        /// sunnah: what to do, its result, the small line above it, grade · source
        var fp: String? = nil
        var stateId: Int? = nil
        var todo: String? = nil
        var fruit: String? = nil
        var time: String? = nil
        var meta: String? = nil
        /// text (a situation of «ماذا تشعر الآن؟», a state of the sunan): title, line under it, link
        var title: String? = nil
        var sub: String? = nil
        var link: String? = nil
    }

    private static let service = "ilm.widget"
    private static let account = "choice"

    private static var base: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    /// The reader's choice; nil = «تلقائي».
    static func load() -> WidgetChoice? {
        var q = base
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data,
              let c = try? JSONDecoder().decode(WidgetChoice.self, from: data), !c.items.isEmpty else { return nil }
        return c
    }

    /// Writes the choice (nil = «تلقائي»). Readable after the first unlock, so the lock screen can draw it.
    static func save(_ c: WidgetChoice?) {
        SecItemDelete(base as CFDictionary)
        guard let c, !c.items.isEmpty, let data = try? JSONEncoder().encode(c) else { return }
        var q = base
        q[kSecValueData as String] = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(q as CFDictionary, nil)
    }
}
