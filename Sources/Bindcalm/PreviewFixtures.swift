import Foundation
import BindcalmCore

/// Deterministic app states for design review and screenshots.
/// Launch with `BINDCALM_PREVIEW=<scenario>` (see `PreviewScenario`); nothing here runs in normal use.
enum PreviewScenario: String, CaseIterable {
    case main
    case nothingSelected = "nothing-selected"
    case noConflicts = "no-conflicts"
    case noResults = "no-results"
    case scanning
    case permission
    case scanFailed = "scan-failed"
    case methods
    case captureOff = "capture-off"
    case captureWaiting = "capture-waiting"
    case captureLog = "capture-log"
    case diagnostics

    static func fromEnvironment() -> PreviewScenario? {
        ProcessInfo.processInfo.environment["BINDCALM_PREVIEW"].flatMap(PreviewScenario.init(rawValue:))
    }
}

extension AppModel {
    func apply(_ scenario: PreviewScenario) {
        layouts = PreviewFixtures.layouts
        permissions = PreviewFixtures.permissions(accessibility: true, input: true)
        results = PreviewFixtures.results(.healthy)
        findings = PreviewFixtures.findings
        regroup()
        selection = groups.first { $0.combo.display == "⌘Space" }?.id ?? groups.first?.id

        switch scenario {
        case .main:
            break
        case .nothingSelected:
            selection = nil
        case .noConflicts:
            findings = PreviewFixtures.findings.filter { $0.owner.name != "Alfred" && $0.owner.name != "Raycast"
                && $0.owner.name != "CleanShot X" && $0.owner.name != "Hammerspoon" && $0.action != "Comment Selection" }
            regroup()
            onlyConflicts = true
            selection = nil
        case .noResults:
            searchText = "⌘⇧9"
            selection = nil
        case .scanning:
            findings = []
            groups = []
            results = []
            isScanning = true
            selection = nil
        case .permission:
            findings = []
            groups = []
            permissions = PreviewFixtures.permissions(accessibility: false, input: false)
            results = PreviewFixtures.results(.needsPermission)
            selection = nil
        case .scanFailed:
            findings = []
            groups = []
            results = PreviewFixtures.results(.failed)
            selection = nil
        case .methods:
            showMethods = true
        case .captureOff:
            showCapture = true
            previewCapture = CaptureDisplay(isRunning: false, tapActive: false, monitorsActive: false,
                                            message: nil, observations: [])
        case .captureWaiting:
            showCapture = true
            previewCapture = CaptureDisplay(isRunning: true, tapActive: true, monitorsActive: true,
                                            message: nil, observations: [])
        case .captureLog:
            showCapture = true
            previewCapture = CaptureDisplay(isRunning: true, tapActive: true, monitorsActive: true,
                                            message: nil, observations: PreviewFixtures.observations)
        case .diagnostics:
            showDiagnostics = true
        }
    }
}

enum PreviewFixtures {
    private static let macOS = HotKeyOwner.macOS
    private static let alfred = HotKeyOwner(name: "Alfred", bundleID: "com.runningwithcrayons.Alfred")
    private static let raycast = HotKeyOwner(name: "Raycast", bundleID: "com.raycast.macos")
    private static let cleanShot = HotKeyOwner(name: "CleanShot X", bundleID: "pl.maketheweb.cleanshotx")
    private static let hammerspoon = HotKeyOwner(name: "Hammerspoon", bundleID: "org.hammerspoon.Hammerspoon")
    private static let slack = HotKeyOwner(name: "Slack", bundleID: "com.tinyspeck.slackmacgap")
    private static let safari = HotKeyOwner(name: "Safari", bundleID: "com.apple.Safari")
    private static let terminal = HotKeyOwner(name: "Terminal", bundleID: "com.apple.Terminal")
    private static let xcode = HotKeyOwner(name: "Xcode", bundleID: "com.apple.dt.Xcode")
    private static let notes = HotKeyOwner(name: "Notes", bundleID: "com.apple.Notes")

    private static func combo(_ code: UInt16, _ mods: ModifierSet) -> KeyCombo { KeyCombo(keyCode: code, modifiers: mods) }

    private static func hot(_ combo: KeyCombo, _ owner: HotKeyOwner, _ method: DiscoveryMethod,
                            _ confidence: Confidence, _ scope: HotKeyScope, _ action: String, source: String,
                            enabled: Bool = true, character: String? = nil) -> DiscoveredHotKey {
        DiscoveredHotKey(combo: combo, owner: owner, method: method, confidence: confidence, scope: scope,
                         action: action, enabled: enabled, source: source, definingCharacter: character)
    }

    static let findings: [DiscoveredHotKey] = {
        let space = combo(49, .command)
        let shot = combo(21, [.command, .shift])
        let hyperT = combo(17, [.control, .option, .command])
        let cmdK = combo(40, .command)
        let cmdT = combo(17, .command)
        let cmdComma = combo(43, .command)
        let cmdN = combo(45, .command)
        let cmdShiftK = combo(40, [.command, .shift])
        let cmdD = combo(2, .command)
        let cmdB = combo(11, .command)
        let optSpace = combo(49, .option)
        return [
            hot(space, macOS, .symbolicHotKeys, .reliable, .global, "Show Spotlight search",
                source: "com.apple.symbolichotkeys · AppleSymbolicHotKeys 64"),
            hot(space, alfred, .alfred, .partial, .global, "Alfred Hotkey",
                source: "~/Library/Application Support/Alfred/Alfred.alfredpreferences"),
            hot(space, raycast, .raycast, .partial, .global, "Raycast Hotkey",
                source: "~/Library/Preferences/com.raycast.macos.plist"),
            hot(shot, macOS, .symbolicHotKeys, .reliable, .global, "Save picture of selected area as a file",
                source: "com.apple.symbolichotkeys · AppleSymbolicHotKeys 30"),
            hot(shot, cleanShot, .preferencesScan, .heuristic, .global, "Capture Area",
                source: "pl.maketheweb.cleanshotx · KeyboardShortcuts_captureArea"),
            hot(hyperT, hammerspoon, .hammerspoon, .partial, .global, "Open terminal",
                source: "~/.hammerspoon/init.lua:18"),
            hot(hyperT, terminal, .accessibilityMenus, .reliable, .inApp, "New Tab",
                source: "AX: Shell ▸ New Tab"),
            hot(cmdShiftK, slack, .accessibilityMenus, .reliable, .inApp, "Threads",
                source: "AX: Go ▸ Threads"),
            hot(cmdShiftK, safari, .accessibilityMenus, .reliable, .inApp, "Show Bookmarks Sidebar",
                source: "AX: View ▸ Show Bookmarks"),
            hot(cmdK, slack, .accessibilityMenus, .reliable, .inApp, "Open Quick Switcher",
                source: "AX: Go ▸ Quick Switcher"),
            hot(cmdK, xcode, .accessibilityMenus, .reliable, .inApp, "Clean Console",
                source: "AX: Product ▸ Clean Console"),
            hot(cmdT, safari, .accessibilityMenus, .reliable, .inApp, "New Tab", source: "AX: File ▸ New Tab"),
            hot(cmdT, xcode, .accessibilityMenus, .reliable, .inApp, "Show Fonts", source: "AX: Format ▸ Font"),
            hot(cmdComma, safari, .accessibilityMenus, .reliable, .inApp, "Settings…", source: "AX: Safari ▸ Settings…"),
            hot(cmdN, notes, .accessibilityMenus, .reliable, .inApp, "New Note", source: "AX: File ▸ New Note"),
            hot(cmdD, safari, .accessibilityMenus, .reliable, .inApp, "Add Bookmark…", source: "AX: Bookmarks ▸ Add Bookmark…"),
            hot(cmdB, notes, .accessibilityMenus, .reliable, .inApp, "Bold", source: "AX: Format ▸ Font ▸ Bold"),
            hot(combo(44, .command), xcode, .accessibilityMenus, .heuristic, .inApp, "Comment Selection",
                source: "AX: Editor ▸ Structure ▸ Comment Selection", character: "/"),
            hot(combo(27, .command), macOS, .symbolicHotKeys, .reliable, .global, "Zoom out",
                source: "com.apple.symbolichotkeys · AppleSymbolicHotKeys 19"),
            hot(optSpace, macOS, .symbolicHotKeys, .reliable, .global, "Select the previous input source",
                source: "com.apple.symbolichotkeys · AppleSymbolicHotKeys 60", enabled: false),
        ]
    }()

    static let layouts = LayoutSnapshot(layouts: [
        .init(id: "com.apple.keylayout.ABC", name: "ABC", isCurrent: true, isASCIICapable: true,
              unshifted: [49: " ", 21: "4", 40: "k", 17: "t", 44: "/"], shifted: [21: "$", 40: "K", 17: "T"]),
        .init(id: "com.apple.keylayout.Dvorak", name: "Dvorak", isCurrent: false, isASCIICapable: true,
              unshifted: [49: " ", 27: "/", 44: "z"], shifted: [27: "?"]),
        .init(id: "com.apple.keylayout.Ukrainian-PC", name: "Ukrainian", isCurrent: false, isASCIICapable: false,
              unshifted: [49: " ", 21: "4", 40: "л", 17: "е"], shifted: [21: ";", 40: "Л", 17: "Е"]),
    ], perDocumentInputSource: false)

    enum ResultSet { case healthy, needsPermission, failed }

    static func results(_ set: ResultSet) -> [StrategyRunResult] {
        func json(_ method: String, _ name: String, _ state: String, _ count: Int, _ message: String?, _ ms: Int) -> String {
            let msg = message.map { "\"\($0)\"" } ?? "null"
            return "{\"method\":\"\(method)\",\"displayName\":\"\(name)\",\"state\":\"\(state)\",\"count\":\(count),\"message\":\(msg),\"durationMs\":\(ms)}"
        }
        let rows: [String]
        switch set {
        case .healthy:
            rows = [
                json("symbolicHotKeys", "System shortcuts (plist)", "ok", 3, nil, 4),
                json("skyLightSymbolic", "System shortcuts (SkyLight)", "ok", 3, nil, 2),
                json("carbonProbe", "Carbon probe", "ok", 5, nil, 31),
                json("userKeyEquivalents", "Custom menu shortcuts", "ok", 0, nil, 3),
                json("preferencesScan", "App preferences scan", "ok", 1, nil, 212),
                json("alfred", "Alfred", "ok", 1, nil, 9),
                json("raycast", "Raycast", "ok", 1, nil, 6),
                json("hammerspoon", "Hammerspoon", "ok", 1, nil, 5),
                json("accessibilityMenus", "Accessibility menus", "needsPermission", 0, "Accessibility permission required", 1),
                json("cgEventTap", "CGEvent tap (live)", "disabled", 0, nil, 0),
            ]
        case .needsPermission:
            rows = [
                json("accessibilityMenus", "Accessibility menus", "needsPermission", 0, "Accessibility permission required", 1),
                json("cgEventTap", "CGEvent tap (live)", "needsPermission", 0, "Input Monitoring permission required", 1),
            ]
        case .failed:
            rows = [
                json("symbolicHotKeys", "System shortcuts (plist)", "failed", 0, "Could not read com.apple.symbolichotkeys", 3),
                json("preferencesScan", "App preferences scan", "failed", 0, "Operation not permitted", 18),
                json("carbonProbe", "Carbon probe", "unavailable", 0, "Private symbol not found", 1),
            ]
        }
        let data = Data("[\(rows.joined(separator: ","))]".utf8)
        return (try? JSONDecoder().decode([StrategyRunResult].self, from: data)) ?? []
    }

    static func permissions(accessibility: Bool, input: Bool) -> PermissionSnapshot {
        let json = "{\"accessibility\":\(accessibility),\"inputMonitoring\":\(input),\"secureInput\":false}"
        return (try? JSONDecoder().decode(PermissionSnapshot.self, from: Data(json.utf8)))
            ?? Permissions.snapshot()
    }

    static var observations: [LiveObservation] {
        func make(_ id: String, _ combo: KeyCombo, _ seconds: Double, _ front: HotKeyOwner, tap: Bool,
                  global: Bool, local: Bool) -> LiveObservation? {
            struct Payload: Encodable {
                var id: String; var combo: KeyCombo; var time: Double; var frontmost: HotKeyOwner
                var axFocusedApp: String; var ourAppActive: Bool; var seenByTap: Bool
                var seenByGlobalMonitor: Bool; var seenByLocalMonitor: Bool
            }
            let payload = Payload(id: id, combo: combo, time: seconds, frontmost: front, axFocusedApp: front.name,
                                  ourAppActive: false, seenByTap: tap, seenByGlobalMonitor: global, seenByLocalMonitor: local)
            guard let data = try? JSONEncoder().encode(payload) else { return nil }
            return try? JSONDecoder().decode(LiveObservation.self, from: data)
        }
        // Reference date 2001-01-01 + 811,000,000 s ≈ mid-September 2026; only the time of day is displayed.
        let base: Double = 811_000_000 + 11 * 3600 + 24 * 60
        let space = combo(49, .command)
        let shot = combo(21, [.command, .shift])
        let cmdT = combo(17, .command)
        return [
            make("00000000-0000-0000-0000-000000000003", cmdT, base + 41, safari, tap: true, global: true, local: false),
            make("00000000-0000-0000-0000-000000000002", shot, base + 20, safari, tap: true, global: false, local: false),
            make("00000000-0000-0000-0000-000000000001", space, base, terminal, tap: true, global: false, local: false),
        ].compactMap { $0 }
    }
}
