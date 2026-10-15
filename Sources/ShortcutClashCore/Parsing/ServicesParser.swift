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

/// How an Info.plist default is reported once `NSServicesStatus` has been consulted.
public struct ResolvedServiceDefault: Hashable, Sendable {
    public var combo: KeyCombo
    public var enabled: Bool
    /// True when pbs has an entry for this service, so the enabled flag is the user's setting.
    public var confirmed: Bool
    public var definingCharacter: String
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
    ///
    /// pbs writes an entry when the user changes a service, and System Settings materialises entries
    /// when the Services list is opened. It does not publish the effective state of an untouched
    /// default. `enabled_services_menu` is the keyboard-shortcut gate; `enabled_context_menu` is used
    /// only when that key is absent. Missing both flags means the entry does not confirm the service
    /// is on, so it is disabled.
    public static func parseStatus(_ status: [String: Any], layouts: LayoutSnapshot = .empty) -> [ServiceStatusEntry] {
        status.compactMap { key, raw in
            guard let dict = raw as? [String: Any] else { return nil }
            let parts = key.components(separatedBy: " - ")
            let provider = parts.first.flatMap { $0 == "(null)" || $0.isEmpty ? nil : $0 }
            let title = parts.count >= 2 ? parts[1] : key
            let combo = (dict["key_equivalent"] as? String).flatMap {
                KeyEquivalentParser.parseUserKeyEquivalent($0, layouts: layouts)
            }
            let enabled = ConfigFiles.enabledFlag(in: dict, keys: ["enabled_services_menu", "enabled_context_menu"], default: false)
            return ServiceStatusEntry(providerBundleID: provider, title: title, combo: combo, enabled: enabled, rawKey: key)
        }
    }

    /// Info.plist default for one service.
    /// - Returns nil when `status` already has its own `key_equivalent` (that entry is the claim).
    /// - A status entry without a shortcut keeps the plist combo and the status enabled flag.
    /// - No status entry at all: the default is disabled, because its effective state is unknown.
    public static func resolveDefault(_ shortcut: ServiceShortcut, status: ServiceStatusEntry?) -> ResolvedServiceDefault? {
        if let status, status.combo != nil { return nil }
        return ResolvedServiceDefault(combo: shortcut.combo,
                                      enabled: status?.enabled ?? false,
                                      confirmed: status != nil,
                                      definingCharacter: shortcut.character)
    }
}
