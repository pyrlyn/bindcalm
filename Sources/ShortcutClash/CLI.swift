import Foundation
import ShortcutClashCore

enum CLI {
    static let help = """
    Usage: ShortcutClash [--dump [--summary] [--methods id,id] [--all-methods]] [--probe-symbols]

      --dump           Run the enabled strategies once and print a JSON report to stdout.
      --summary        With --dump: print a short human-readable summary instead of JSON.
      --methods        Comma-separated strategy ids to run (default: the app's default set).
      --all-methods    Run every strategy, including ones that are off by default.
      --probe-symbols  Print which private/undocumented symbols resolve via dlsym.

    Strategy ids: \(DiscoveryMethod.allCases.map(\.rawValue).joined(separator: ", "))
    """

    static func run(_ args: [String]) -> Never {
        if args.contains("--help") {
            print(help)
            exit(0)
        }
        Task { @MainActor in
            if args.contains("--probe-symbols") {
                for result in PrivateSymbols.probeAll() {
                    let mark = result.found ? "FOUND  " : "missing"
                    print("\(mark) \(result.name.padding(toLength: 34, withPad: " ", startingAt: 0)) \(result.image ?? "-")  // \(result.note)")
                }
                if !args.contains("--dump") { exit(0) }
            }
            await dump(args)
            exit(0)
        }
        dispatchMain()
    }

    @MainActor
    static func dump(_ args: [String]) async {
        var enabled = StrategyRegistry.defaultEnabled
        if args.contains("--all-methods") { enabled = Set(DiscoveryMethod.allCases) }
        if let index = args.firstIndex(of: "--methods"), index + 1 < args.count {
            enabled = Set(args[index + 1].split(separator: ",").compactMap { DiscoveryMethod(rawValue: String($0)) })
        }
        let context = DiscoveryContext(layouts: LayoutService.snapshot())
        let outcome = await ScanEngine.run(enabled: enabled, context: context)
        let groups = ConflictAnalyzer.groups(from: outcome.findings, layouts: outcome.layouts)
        let report = DumpReport(outcome: outcome, groups: groups, permissions: Permissions.snapshot())

        if args.contains("--summary") {
            printSummary(report, groups: groups)
        } else if let data = try? report.jsonData() {
            FileHandle.standardOutput.write(data)
            print()
        }
    }

    static func printSummary(_ report: DumpReport, groups: [HotKeyGroup]) {
        print("Permissions: accessibility=\(report.permissions.accessibility) inputMonitoring=\(report.permissions.inputMonitoring) secureInput=\(report.permissions.secureInput)")
        print("Layouts: \(report.layouts.map { "\($0.name)\($0.isCurrent ? "*" : "")\($0.isASCIICapable ? "" : " (non-ASCII)")" }.joined(separator: ", ")); perDocumentInputSource=\(report.perDocumentInputSource.map(String.init) ?? "n/a")")
        print("\nStrategies:")
        for result in report.strategies {
            let msg = result.message.map { " — \($0)" } ?? ""
            print("  \(result.method.rawValue.padding(toLength: 20, withPad: " ", startingAt: 0)) \(result.state.rawValue.padding(toLength: 16, withPad: " ", startingAt: 0)) \(String(result.count).padding(toLength: 6, withPad: " ", startingAt: 0)) \(result.durationMs) ms\(msg)")
        }
        let counts = Dictionary(grouping: groups, by: \.status).mapValues(\.count)
        print("\nGroups: \(groups.count) combos; conflict=\(counts[.conflict] ?? 0) layoutConflict=\(counts[.layoutConflict] ?? 0) inAppDuplicate=\(counts[.inAppDuplicate] ?? 0)")
        print("\nConflict examples:")
        for group in groups.filter(\.isProblem).prefix(15) {
            let parts = group.findings.filter { $0.enabled && $0.scope != .observed }.map {
                "\($0.owner.name) [\($0.scope.rawValue), \($0.method.rawValue)] \($0.action ?? "")"
            }
            print("  \(group.combo.display): " + Array(Set(parts)).sorted().prefix(4).joined(separator: " | "))
        }
    }
}
