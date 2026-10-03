import Foundation

public struct ServiceShortcut: Hashable, Sendable {
    public var title: String
    public var combo: KeyCombo
    public var character: String
}

public struct ServiceStatusEntry: Hashable, Sendable {
    public var providerBundleID: String?
    public var title: String
    public var combo: KeyCombo?
    public var enabled: Bool
    public var rawKey: String
}

public enum ServicesParser {
    /// `NSServices` entries in an app's Info.plist. Service key equivalents are always Command-based;
    /// an uppercase letter adds Shift.
    public static func parseInfoPlistServices(_ services: [[String: Any]]) -> [ServiceShortcut] {
        services.compactMap { item in
            guard let keyDict = item["NSKeyEquivalent"] as? [String: Any],
                  let key = keyDict["default"] as? String, key.count == 1 else { return nil }
            let title = (item["NSMenuItem"] as? [String: Any])?["default"] as? String
                ?? item["NSMessage"] as? String ?? "?"
            guard let combo = KeyEquivalentParser.combo(forCharacter: key, modifiers: .command,
                                                        uppercaseImpliesShift: true) else { return nil }
            return ServiceShortcut(title: title, combo: combo, character: key)
        }
    }

    /// `pbs` → `NSServicesStatus`: keys look like "com.apple.Terminal - Open man Page - openManPage"
    /// (or "(null) - Name - runWorkflowAsService" for Shortcuts/Automator quick actions).
    public static func parseStatus(_ status: [String: Any], layouts: LayoutSnapshot = .empty) -> [ServiceStatusEntry] {
        status.compactMap { key, raw in
            guard let dict = raw as? [String: Any] else { return nil }
            let parts = key.components(separatedBy: " - ")
            let provider = parts.first.flatMap { $0 == "(null)" || $0.isEmpty ? nil : $0 }
            let title = parts.count >= 2 ? parts[1] : key
            let combo = (dict["key_equivalent"] as? String).flatMap {
                KeyEquivalentParser.parseUserKeyEquivalent($0, layouts: layouts)
            }
            let enabled = (dict["enabled_services_menu"] as? NSNumber)?.boolValue
                ?? (dict["enabled_context_menu"] as? NSNumber)?.boolValue ?? true
            return ServiceStatusEntry(providerBundleID: provider, title: title, combo: combo, enabled: enabled, rawKey: key)
        }
    }
}
