import Foundation

/// Reads `com.apple.symbolichotkeys` through cfprefsd (so unsaved in-memory changes are included).
/// The plist only lists hotkeys the system or user has written; untouched defaults may be absent —
/// `SkyLightSymbolicStrategy` covers those.
public struct SymbolicHotKeysPlistStrategy: HotKeyDiscoveryStrategy {
    public init() {}
    public var id: DiscoveryMethod { .symbolicHotKeys }
    public var displayName: String { "Системные сочетания (plist)" }
    public var summary: String { "com.apple.symbolichotkeys → AppleSymbolicHotKeys: Spotlight, Mission Control, снимки экрана, источники ввода. Надёжно, но только записанные значения." }

    public func discover(in context: DiscoveryContext) async throws -> [DiscoveredHotKey] {
        let domain = "com.apple.symbolichotkeys"
        var root = CFPreferencesCopyAppValue("AppleSymbolicHotKeys" as CFString, domain as CFString) as? [String: Any]
        if root == nil {
            let url = context.home.appendingPathComponent("Library/Preferences/\(domain).plist")
            if let data = try? Data(contentsOf: url),
               let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
                root = plist["AppleSymbolicHotKeys"] as? [String: Any]
            }
        }
        guard let root else { throw DiscoveryError.unavailable("Не удалось прочитать com.apple.symbolichotkeys") }
        return SymbolicHotKeysParser.parse(root).compactMap { entry in
            guard let combo = entry.combo else { return nil }
            return DiscoveredHotKey(combo: combo, owner: .macOS, method: id, confidence: .reliable, scope: .global,
                                    action: SymbolicHotKeysParser.name(for: entry.id), enabled: entry.enabled,
                                    source: "\(domain) → AppleSymbolicHotKeys[\(entry.id)]")
        }
    }
}
