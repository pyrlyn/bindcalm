import Foundation

/// JSON produced by `--dump` and by the UI export.
public struct DumpReport: Codable, Sendable {
    public struct Group: Codable, Sendable {
        public var combo: KeyCombo
        public var status: ConflictStatus
        public var owners: [String]
        public var methods: [DiscoveryMethod]
        public var layoutNotes: [LayoutNote]
    }

    public struct LayoutSummary: Codable, Sendable {
        public var id: String
        public var name: String
        public var isCurrent: Bool
        public var isASCIICapable: Bool
    }

    public var generatedAt: Date
    public var osVersion: String
    public var permissions: PermissionSnapshot
    public var strategies: [StrategyRunResult]
    public var layouts: [LayoutSummary]
    public var perDocumentInputSource: Bool?
    public var privateSymbols: [SymbolProbeResult]
    public var groups: [Group]
    public var findings: [DiscoveredHotKey]

    public init(outcome: ScanOutcome, groups: [HotKeyGroup], permissions: PermissionSnapshot) {
        generatedAt = Date()
        osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        self.permissions = permissions
        strategies = outcome.results
        layouts = outcome.layouts.layouts.map { LayoutSummary(id: $0.id, name: $0.name, isCurrent: $0.isCurrent, isASCIICapable: $0.isASCIICapable) }
        perDocumentInputSource = outcome.layouts.perDocumentInputSource
        privateSymbols = PrivateSymbols.probeAll()
        self.groups = groups.map {
            Group(combo: $0.combo, status: $0.status, owners: $0.owners.map(\.name), methods: $0.methods, layoutNotes: $0.layoutNotes)
        }
        findings = outcome.findings.sorted { ($0.combo.display, $0.method.rawValue) < ($1.combo.display, $1.method.rawValue) }
    }

    public func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
}
