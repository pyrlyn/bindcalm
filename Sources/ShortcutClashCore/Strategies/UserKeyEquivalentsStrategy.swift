import Foundation

/// Custom menu shortcuts set in System Settings → Keyboard → App Shortcuts (`NSUserKeyEquivalents`).
public struct UserKeyEquivalentsStrategy: HotKeyDiscoveryStrategy {
    public init() {}
    public var id: DiscoveryMethod { .userKeyEquivalents }
    public var displayName: String { "Пользовательские сочетания меню (NSUserKeyEquivalents)" }
    public var summary: String { "Сочетания из «Клавиатура → Сочетания клавиш → Сочетания приложений» для каждого приложения и для всех (NSGlobalDomain). Надёжно." }

    public func discover(in context: DiscoveryContext) async throws -> [DiscoveredHotKey] {
        var found: [DiscoveredHotKey] = []
        if let global = copy(kCFPreferencesAnyApplication) {
            found += makeFindings(global, owner: .allApps, domain: "NSGlobalDomain", context: context)
        }
        for bundleID in InstalledApps.knownBundleIDs(home: context.home).sorted() {
            // CFPreferencesCopyValue (not CopyAppValue) so NSGlobalDomain entries are not re-reported per app.
            guard let dict = copy(bundleID as CFString) else { continue }
            found += makeFindings(dict, owner: context.owners.owner(bundleID: bundleID), domain: bundleID, context: context)
        }
        return found
    }

    private func copy(_ domain: CFString) -> [String: String]? {
        CFPreferencesCopyValue("NSUserKeyEquivalents" as CFString, domain, kCFPreferencesCurrentUser,
                               kCFPreferencesAnyHost) as? [String: String]
    }

    private func makeFindings(_ dict: [String: String], owner: HotKeyOwner, domain: String,
                              context: DiscoveryContext) -> [DiscoveredHotKey] {
        dict.compactMap { title, equivalent in
            guard let combo = KeyEquivalentParser.parseUserKeyEquivalent(equivalent, layouts: context.layouts) else { return nil }
            return DiscoveredHotKey(combo: combo, owner: owner, method: id, confidence: .reliable, scope: .inApp,
                                    action: title.replacingOccurrences(of: "\u{1B}", with: " → "),
                                    source: "\(domain) → NSUserKeyEquivalents = \"\(equivalent)\"",
                                    definingCharacter: equivalent.last.map(String.init))
        }
    }
}
