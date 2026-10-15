import AppKit
import Combine
import ShortcutClashCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var findings: [DiscoveredHotKey] = []
    @Published private(set) var groups: [HotKeyGroup] = []
    @Published private(set) var results: [StrategyRunResult] = []
    @Published private(set) var layouts: LayoutSnapshot = .empty
    @Published private(set) var isScanning = false
    @Published private(set) var permissions = Permissions.snapshot()
    @Published private(set) var lastScan: Date?

    @Published var enabled: Set<DiscoveryMethod> { didSet { persistMethods() } }
    @Published var layoutAnalysis: Bool { didSet { defaults.set(layoutAnalysis, forKey: Keys.layoutAnalysis); regroup() } }
    @Published var onlyConflicts = false
    @Published var showDuplicates: Bool { didSet { defaults.set(showDuplicates, forKey: Keys.showDuplicates) } }
    @Published var methodFilter: DiscoveryMethod?
    @Published var appFilter: String?
    @Published var searchText = ""
    @Published var selection: HotKeyGroup.ID?

    let capture = LiveCaptureController()
    let strategies = StrategyRegistry.all

    private let defaults = UserDefaults.standard
    private var registryFindings: [DiscoveredHotKey] = []
    private var cancellables: Set<AnyCancellable> = []
    private var scanTask: Task<Void, Never>?
    private var menuWatchTask: Task<Void, Never>?
    private var activationObserver: NSObjectProtocol?
    /// Bumped on every full rescan so an in-flight menu refresh cannot overwrite newer results.
    private var scanGeneration = 0

    private enum Keys {
        static let methods = "enabledMethods"
        static let layoutAnalysis = "layoutAnalysisEnabled"
        static let showDuplicates = "showInAppDuplicates"
    }

    init() {
        if let stored = defaults.stringArray(forKey: Keys.methods) {
            enabled = Set(stored.compactMap(DiscoveryMethod.init(rawValue:)))
        } else {
            enabled = StrategyRegistry.defaultEnabled
        }
        layoutAnalysis = defaults.object(forKey: Keys.layoutAnalysis) as? Bool ?? true
        showDuplicates = defaults.object(forKey: Keys.showDuplicates) as? Bool ?? true

        capture.$observations
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.mergeLiveFindings() }
            .store(in: &cancellables)

        // TCC changes are not notified to the app; polling is the documented-by-practice approach.
        Timer.publish(every: 2, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.refreshPermissions() }
            .store(in: &cancellables)

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated {
                guard let self, let app else { return }
                self.refreshFrontmostMenus(of: app)
            }
        }

        rescan()
    }

    deinit {
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
    }

    // MARK: - Scanning

    func rescan() {
        scanGeneration += 1
        menuWatchTask?.cancel()
        scanTask?.cancel()
        isScanning = true
        let snapshot = LayoutService.snapshot()
        layouts = snapshot
        let context = DiscoveryContext(layouts: snapshot)
        let enabledNow = enabled
        scanTask = Task {
            let outcome = await ScanEngine.run(strategies: strategies, enabled: enabledNow, context: context)
            guard !Task.isCancelled else { return }
            registryFindings = outcome.findings.filter { $0.scope != .observed }
            results = outcome.results
            lastScan = Date()
            isScanning = false
            mergeLiveFindings()
        }
    }

    private func mergeLiveFindings() {
        let liveIDs = Set(strategies.filter(\.isLiveCapture).map(\.id)).intersection(enabled)
        let context = DiscoveryContext(layouts: layouts)
        Task {
            var live: [DiscoveredHotKey] = []
            for strategy in strategies where liveIDs.contains(strategy.id) {
                live += (try? await strategy.discover(in: context)) ?? []
            }
            findings = registryFindings + live
            regroup()
        }
    }

    private func regroup() {
        groups = ConflictAnalyzer.groups(from: findings, layouts: layoutAnalysis ? layouts : nil)
    }

    func refreshPermissions() {
        let now = Permissions.snapshot()
        let gainedAccessibility = now.accessibility && !permissions.accessibility
        if now != permissions { permissions = now }
        if gainedAccessibility, let app = NSWorkspace.shared.frontmostApplication {
            refreshFrontmostMenus(of: app)
        }
    }

    /// Re-reads the activated app's menus. Does not prompt for Accessibility and does not rescan other strategies.
    private func refreshFrontmostMenus(of app: NSRunningApplication) {
        guard !isScanning, enabled.contains(.accessibilityMenus) else { return }
        let generation = scanGeneration
        let context = DiscoveryContext(layouts: layouts)
        let ownerKey = context.owners.owner(for: app).key
        menuWatchTask?.cancel()
        menuWatchTask = Task {
            let fresh = AccessibilityMenuStrategy().menuClaims(of: app, in: context)
            guard !Task.isCancelled, generation == scanGeneration, let fresh else { return }
            registryFindings = MenuClaimRefresh.apply(ownerKey: ownerKey, fresh: fresh, to: registryFindings)
            mergeLiveFindings()
        }
    }

    private func persistMethods() {
        defaults.set(enabled.map(\.rawValue).sorted(), forKey: Keys.methods)
    }

    func binding(for method: DiscoveryMethod) -> Binding<Bool> {
        Binding(get: { self.enabled.contains(method) },
                set: { on in if on { self.enabled.insert(method) } else { self.enabled.remove(method) } })
    }

    func result(for method: DiscoveryMethod) -> StrategyRunResult? {
        results.first { $0.method == method }
    }

    // MARK: - Filtering

    var filteredGroups: [HotKeyGroup] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return groups.filter { group in
            if onlyConflicts, !(group.isProblem || (showDuplicates && group.status == .inAppDuplicate)) { return false }
            if let methodFilter, !group.findings.contains(where: { $0.method == methodFilter }) { return false }
            if let appFilter, !group.owners.contains(where: { $0.key == appFilter }) { return false }
            guard !query.isEmpty else { return true }
            if group.combo.display.lowercased().contains(query) { return true }
            return group.findings.contains {
                $0.owner.name.lowercased().contains(query)
                    || ($0.owner.bundleID?.lowercased().contains(query) ?? false)
                    || ($0.action?.lowercased().contains(query) ?? false)
            }
        }
    }

    var allOwners: [HotKeyOwner] {
        var seen = Set<String>()
        return findings.compactMap { seen.insert($0.owner.key).inserted ? $0.owner : nil }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var conflictCount: Int { groups.filter(\.isProblem).count }

    func group(with id: HotKeyGroup.ID?) -> HotKeyGroup? {
        guard let id else { return nil }
        return groups.first { $0.id == id }
    }

    func observations(for combo: KeyCombo) -> [LiveObservation] {
        capture.observations.filter { $0.combo == combo }
    }

    func registryOwners(for combo: KeyCombo) -> [HotKeyOwner] {
        groups.first { $0.combo == combo }?.owners ?? []
    }

    // MARK: - Actions

    func requestAccessibility() {
        Permissions.requestAccessibility()
        refreshPermissions()
    }

    func requestInputMonitoring() {
        Permissions.requestInputMonitoring()
        refreshPermissions()
    }

    func toggleCapture() {
        if capture.isRunning {
            capture.stop()
        } else {
            capture.useEventTap = enabled.contains(.cgEventTap)
            capture.useMonitors = enabled.contains(.nsEventMonitor)
            capture.start()
        }
    }

    func exportJSON() {
        let outcome = ScanOutcome(findings: findings, results: results, layouts: layouts)
        let report = DumpReport(outcome: outcome, groups: groups, permissions: permissions)
        guard let data = try? report.jsonData() else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "shortcutclash-report.json"
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }
}
