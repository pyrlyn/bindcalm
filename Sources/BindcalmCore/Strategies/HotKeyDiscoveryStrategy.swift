import Foundation

/// Everything a strategy may need, captured once per scan.
public struct DiscoveryContext: Sendable {
    public var layouts: LayoutSnapshot
    public var owners: OwnerResolver
    public var home: URL
    public var ownBundleID: String?

    public init(layouts: LayoutSnapshot, owners: OwnerResolver = OwnerResolver(),
                home: URL = FileManager.default.homeDirectoryForCurrentUser,
                ownBundleID: String? = Bundle.main.bundleIdentifier) {
        self.layouts = layouts
        self.owners = owners
        self.home = home
        self.ownBundleID = ownBundleID
    }
}

public enum DiscoveryError: Error, Sendable, CustomStringConvertible {
    case permissionRequired(PermissionKind)
    case unavailable(String)

    public var description: String {
        switch self {
        case .permissionRequired(.accessibility): return "Нужно разрешение «Универсальный доступ»"
        case .permissionRequired(.inputMonitoring): return "Нужно разрешение «Мониторинг ввода»"
        case .unavailable(let reason): return reason
        }
    }
}

/// One independent detection method. Strategies never depend on each other's results;
/// cross-method reasoning happens later in `ConflictAnalyzer` / `LayoutAnalyzer`.
public protocol HotKeyDiscoveryStrategy: Sendable {
    var id: DiscoveryMethod { get }
    /// Russian, shown in the UI.
    var displayName: String { get }
    /// Russian one-liner explaining what the method reads and how far to trust it.
    var summary: String { get }
    var defaultEnabled: Bool { get }
    var requiredPermission: PermissionKind? { get }
    /// Live strategies only report what the user pressed during capture mode.
    var isLiveCapture: Bool { get }

    func discover(in context: DiscoveryContext) async throws -> [DiscoveredHotKey]
}

public extension HotKeyDiscoveryStrategy {
    var defaultEnabled: Bool { true }
    var requiredPermission: PermissionKind? { nil }
    var isLiveCapture: Bool { false }
}

public enum StrategyRegistry {
    public static let all: [any HotKeyDiscoveryStrategy] = [
        SymbolicHotKeysPlistStrategy(),
        SkyLightSymbolicStrategy(),
        SystemKeysStrategy(),
        UserKeyEquivalentsStrategy(),
        ServicesStrategy(),
        PreferencesScanStrategy(sandboxContainers: false),
        PreferencesScanStrategy(sandboxContainers: true),
        KarabinerStrategy(),
        SkhdStrategy(),
        HammerspoonStrategy(),
        BetterTouchToolStrategy(),
        KeyboardMaestroStrategy(),
        AlfredStrategy(),
        RaycastStrategy(),
        AccessibilityMenuStrategy(),
        CarbonProbeStrategy(),
        NSEventMonitorStrategy(),
        CGEventTapStrategy(),
    ]

    public static func strategy(_ id: DiscoveryMethod) -> (any HotKeyDiscoveryStrategy)? {
        all.first { $0.id == id }
    }

    public static func displayName(_ id: DiscoveryMethod) -> String {
        strategy(id)?.displayName ?? id.rawValue
    }

    public static var defaultEnabled: Set<DiscoveryMethod> {
        Set(all.filter { $0.defaultEnabled }.map { $0.id })
    }
}
