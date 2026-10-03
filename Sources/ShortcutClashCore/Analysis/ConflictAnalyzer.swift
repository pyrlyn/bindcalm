import Foundation

public enum ConflictStatus: String, Codable, Sendable, Comparable {
    /// Two different owners where at least one is global: one of them never fires.
    case conflict
    /// A character-defined shortcut lands on a globally owned combo in another enabled layout.
    case layoutConflict
    /// The same app binds one combo to several of its own menu items.
    case inAppDuplicate
    case none

    private var rank: Int {
        switch self {
        case .conflict: return 0
        case .layoutConflict: return 1
        case .inAppDuplicate: return 2
        case .none: return 3
        }
    }

    public static func < (lhs: ConflictStatus, rhs: ConflictStatus) -> Bool { lhs.rank < rhs.rank }
}

public struct LayoutNote: Hashable, Codable, Sendable {
    public var layoutName: String
    public var message: String
    public var isConflict: Bool
}

/// All claims on one physical combo.
public struct HotKeyGroup: Identifiable, Hashable, Sendable {
    public var combo: KeyCombo
    public var findings: [DiscoveredHotKey]
    public var status: ConflictStatus
    public var layoutNotes: [LayoutNote] = []

    public var id: String { combo.id }

    public var owners: [HotKeyOwner] {
        var seen = Set<String>()
        return findings.filter { $0.scope != .observed }.compactMap { seen.insert($0.owner.key).inserted ? $0.owner : nil }
    }

    /// Owners whose claim is enabled and not mere observation: the parties of a conflict.
    public var activeOwners: [HotKeyOwner] {
        var seen = Set<String>()
        return findings.filter { $0.enabled && $0.scope != .observed }.compactMap { seen.insert($0.owner.key).inserted ? $0.owner : nil }
    }

    public var methods: [DiscoveryMethod] {
        var seen = Set<DiscoveryMethod>()
        return findings.compactMap { seen.insert($0.method).inserted ? $0.method : nil }
    }

    public var hasGlobal: Bool { findings.contains { $0.scope == .global && $0.enabled } }
    public var isProblem: Bool { status == .conflict || status == .layoutConflict }
}

public enum ConflictAnalyzer {
    public static func status(of findings: [DiscoveredHotKey]) -> ConflictStatus {
        let active = findings.filter { $0.enabled && $0.scope != .observed }
        let globals = active.filter { $0.scope == .global }
        let inApp = active.filter { $0.scope == .inApp }

        // Unknown owners (Carbon probe) corroborate a known global owner rather than oppose it.
        let knownGlobalOwners = Set(globals.filter { !$0.owner.isUnknown }.map { $0.owner.key })
        if knownGlobalOwners.count >= 2 { return .conflict }
        if !globals.isEmpty {
            let inAppOwners = Set(inApp.map { $0.owner.key }).subtracting(knownGlobalOwners)
            if !inAppOwners.isEmpty { return .conflict }
        }

        let byOwner = Dictionary(grouping: inApp, by: { $0.owner.key })
        for (_, items) in byOwner {
            let actions = Set(items.map { $0.action ?? "" })
            if actions.count > 1 { return .inAppDuplicate }
        }
        return .none
    }

    public static func groups(from findings: [DiscoveredHotKey], layouts: LayoutSnapshot? = nil) -> [HotKeyGroup] {
        let grouped = Dictionary(grouping: findings, by: { $0.combo })
        var groups = grouped.map { combo, items in
            HotKeyGroup(combo: combo,
                        findings: items.sorted { ($0.owner.name, $0.method.rawValue) < ($1.owner.name, $1.method.rawValue) },
                        status: status(of: items))
        }
        if let layouts {
            groups = LayoutAnalyzer.annotate(groups, layouts: layouts)
        }
        return groups.sorted { lhs, rhs in
            if lhs.status != rhs.status { return lhs.status < rhs.status }
            return lhs.combo.display < rhs.combo.display
        }
    }
}
