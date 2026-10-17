import Foundation

public struct StrategyRunResult: Codable, Sendable, Hashable, Identifiable {
    public enum State: String, Codable, Sendable {
        case ok
        case disabled
        case needsPermission
        case unavailable
        case failed
    }

    public var method: DiscoveryMethod
    public var displayName: String
    public var state: State
    public var count: Int
    public var message: String?
    public var durationMs: Int

    public var id: DiscoveryMethod { method }
}

public struct ScanOutcome: Sendable {
    public var findings: [DiscoveredHotKey]
    public var results: [StrategyRunResult]
    public var layouts: LayoutSnapshot

    public init(findings: [DiscoveredHotKey], results: [StrategyRunResult], layouts: LayoutSnapshot) {
        self.findings = findings
        self.results = results
        self.layouts = layouts
    }
}

public enum ScanEngine {
    /// Runs enabled strategies concurrently; one failing strategy never aborts the scan.
    public static func run(strategies: [any HotKeyDiscoveryStrategy] = StrategyRegistry.all,
                           enabled: Set<DiscoveryMethod>,
                           context: DiscoveryContext) async -> ScanOutcome {
        var results: [StrategyRunResult] = []
        var findings: [DiscoveredHotKey] = []

        await withTaskGroup(of: (StrategyRunResult, [DiscoveredHotKey]).self) { group in
            for strategy in strategies {
                guard enabled.contains(strategy.id) else {
                    results.append(StrategyRunResult(method: strategy.id, displayName: strategy.displayName,
                                                     state: .disabled, count: 0, message: nil, durationMs: 0))
                    continue
                }
                group.addTask {
                    let start = Date()
                    func elapsed() -> Int { Int(Date().timeIntervalSince(start) * 1000) }
                    do {
                        let found = try await strategy.discover(in: context)
                        return (StrategyRunResult(method: strategy.id, displayName: strategy.displayName, state: .ok,
                                                  count: found.count, message: nil, durationMs: elapsed()), found)
                    } catch let error as DiscoveryError {
                        let state: StrategyRunResult.State
                        if case .permissionRequired = error { state = .needsPermission } else { state = .unavailable }
                        return (StrategyRunResult(method: strategy.id, displayName: strategy.displayName, state: state,
                                                  count: 0, message: error.description, durationMs: elapsed()), [])
                    } catch {
                        return (StrategyRunResult(method: strategy.id, displayName: strategy.displayName, state: .failed,
                                                  count: 0, message: String(describing: error), durationMs: elapsed()), [])
                    }
                }
            }
            for await (result, found) in group {
                results.append(result)
                findings.append(contentsOf: found)
            }
        }

        let order = Dictionary(uniqueKeysWithValues: strategies.enumerated().map { ($1.id, $0) })
        results.sort { (order[$0.method] ?? 0) < (order[$1.method] ?? 0) }
        var seen = Set<String>()
        findings = findings.filter { seen.insert($0.id).inserted }
        return ScanOutcome(findings: findings, results: results, layouts: context.layouts)
    }
}
