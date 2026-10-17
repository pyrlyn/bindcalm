import Foundation

/// Identifier of each detection strategy. Raw values are stable: they are persisted and exported.
public enum DiscoveryMethod: String, Codable, CaseIterable, Sendable, Identifiable {
    case symbolicHotKeys
    case skyLightSymbolic
    case carbonProbe
    case userKeyEquivalents
    case preferencesScan
    case sandboxPreferences
    case services
    case karabiner
    case skhd
    case hammerspoon
    case betterTouchTool
    case keyboardMaestro
    case alfred
    case raycast
    case accessibilityMenus
    case systemKeys
    case nsEventMonitor
    case cgEventTap

    public var id: String { rawValue }
}

public enum Confidence: String, Codable, Sendable, Comparable, CaseIterable {
    case reliable
    case partial
    case heuristic

    private var rank: Int {
        switch self {
        case .reliable: return 0
        case .partial: return 1
        case .heuristic: return 2
        }
    }

    public static func < (lhs: Confidence, rhs: Confidence) -> Bool { lhs.rank < rhs.rank }
}

/// Where a shortcut is active. Only `global` shortcuts can steal a key press from another app.
public enum HotKeyScope: String, Codable, Sendable {
    /// System-wide: fires regardless of the frontmost app.
    case global
    /// Menu or key equivalent that fires only while its app is frontmost.
    case inApp
    /// A live key press observation; evidence, never an owner in conflict analysis.
    case observed
}

public struct HotKeyOwner: Hashable, Codable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case app
        case system
        case allApps
        case unknown
    }

    public var name: String
    public var bundleID: String?
    public var path: String?
    public var kind: Kind

    public init(name: String, bundleID: String? = nil, path: String? = nil, kind: Kind = .app) {
        self.name = name
        self.bundleID = bundleID
        self.path = path
        self.kind = kind
    }

    /// Identity used for conflict analysis: the same app found by two methods must compare equal.
    public var key: String {
        switch kind {
        case .system: return "system:macos"
        case .unknown: return "system:unknown"
        case .allApps: return "allapps"
        case .app: return (bundleID ?? name).lowercased()
        }
    }

    public var isUnknown: Bool { kind == .unknown }

    public static let macOS = HotKeyOwner(name: "macOS", bundleID: nil, path: nil, kind: .system)
    public static let unknown = HotKeyOwner(name: "Неизвестно / система", kind: .unknown)
    public static let allApps = HotKeyOwner(name: "Все приложения (NSGlobalDomain)", bundleID: "NSGlobalDomain", kind: .allApps)
}

/// One shortcut claim found by one strategy.
public struct DiscoveredHotKey: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var combo: KeyCombo
    public var owner: HotKeyOwner
    public var method: DiscoveryMethod
    public var confidence: Confidence
    public var scope: HotKeyScope
    /// Menu item title, symbolic hotkey name, preference key, etc.
    public var action: String?
    public var enabled: Bool
    /// Human-readable provenance (file, preference key, AX path).
    public var source: String
    /// Set when the claim was declared as a character rather than a key code; layout analysis needs it.
    public var definingCharacter: String?

    public init(combo: KeyCombo, owner: HotKeyOwner, method: DiscoveryMethod, confidence: Confidence,
                scope: HotKeyScope, action: String? = nil, enabled: Bool = true, source: String,
                definingCharacter: String? = nil) {
        self.combo = combo
        self.owner = owner
        self.method = method
        self.confidence = confidence
        self.scope = scope
        self.action = action
        self.enabled = enabled
        self.source = source
        self.definingCharacter = definingCharacter
        self.id = [method.rawValue, owner.key, combo.id, action ?? "", source].joined(separator: "|")
    }
}
