import Foundation
import Security

/// A collection of «محفوظاتي» shown by a widget (owner 2026-11-26), chosen in «المزيد» — see `WidgetSetup`. The app
/// writes it; the widget extension reads it. It travels in a
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

    /// The item written before each widget had its own choice (`WidgetSetup`): one collection for both.
    fileprivate static let legacyAccount = "choice"

    fileprivate static func loadLegacy() -> WidgetChoice? {
        guard let data = WidgetKeychain.read(legacyAccount),
              let c = try? JSONDecoder().decode(WidgetChoice.self, from: data), !c.items.isEmpty else { return nil }
        return c
    }
}

/// What the home widget shows (owner 2026-11-26 «اعدادات ظهور الودجت ... في اعدادات التطبيق»), chosen in «المزيد»:
/// «تلقائي», «اسم اليوم دائمًا», «سنّة اليوم دائمًا» or a collection of «محفوظاتي». The app writes it into the shared
/// keychain group, the extension reads it. (A `lock` face written by builds 26–27 is ignored when read.)
struct WidgetSetup: Codable, Equatable {
    struct Face: Codable, Equatable {
        /// "auto" | "name" | "sunnah" | "collection"
        var mode: String = "auto"
        /// mode "collection": the collection, already described by the app
        var choice: WidgetChoice? = nil
    }

    var home = Face()

    private static let account = "setup"

    static func load() -> WidgetSetup {
        if let data = WidgetKeychain.read(account), let s = try? JSONDecoder().decode(WidgetSetup.self, from: data) {
            return s
        }
        // written by a version before the setup: the one collection
        if let c = WidgetChoice.loadLegacy() { return WidgetSetup(home: Face(mode: "collection", choice: c)) }
        return WidgetSetup()
    }

    static func save(_ s: WidgetSetup) {
        WidgetKeychain.write(account, try? JSONEncoder().encode(s))
        WidgetKeychain.write(WidgetChoice.legacyAccount, nil)
    }
}

/// A keychain item of the group the app and its widgets share. Readable after the first unlock, so the lock screen
/// can draw it.
enum WidgetKeychain {
    private static func base(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "ilm.widget",
         kSecAttrAccount as String: account]
    }

    static func read(_ account: String) -> Data? {
        var q = base(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess else { return nil }
        return out as? Data
    }

    static func write(_ account: String, _ data: Data?) {
        SecItemDelete(base(account) as CFDictionary)
        guard let data else { return }
        var q = base(account)
        q[kSecValueData as String] = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(q as CFDictionary, nil)
    }
}
