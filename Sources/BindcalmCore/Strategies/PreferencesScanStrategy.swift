import AppKit

/// Heuristic scan of preference plists for shortcut-library storage formats
/// (MASShortcut, sindresorhus/KeyboardShortcuts, ShortcutRecorder, Raycast-style strings, ...).
public struct PreferencesScanStrategy: HotKeyDiscoveryStrategy {
    public let sandboxContainers: Bool

    public init(sandboxContainers: Bool) { self.sandboxContainers = sandboxContainers }

    public var id: DiscoveryMethod { sandboxContainers ? .sandboxPreferences : .preferencesScan }
    public var displayName: String {
        sandboxContainers ? "Настройки песочниц (~/Library/Containers)" : "Эвристика по настройкам (~/Library/Preferences)"
    }
    public var summary: String {
        sandboxContainers
            ? "То же для приложений из песочницы. Чтение чужих контейнеров вызывает запрос macOS «доступ к данным других приложений», поэтому выключено по умолчанию."
            : "Ищет в plist-файлах форматы MASShortcut, KeyboardShortcuts, ShortcutRecorder и строки вида «cmd+shift+k». Эвристика: ключ может быть устаревшим или выключенным."
    }
    public var defaultEnabled: Bool { !sandboxContainers }

    /// Domains read by a dedicated strategy. The heuristic scan would only duplicate them, less accurately.
    static let skippedDomains: Set<String> = [
        "com.apple.symbolichotkeys", "pbs", ".GlobalPreferences",
        "com.raycast.macos", "com.hegenberg.BetterTouchTool",
        "com.stairways.keyboardmaestro", "com.stairways.keyboardmaestro.engine",
        "com.runningwithcrayons.Alfred", "com.runningwithcrayons.Alfred-Preferences",
    ]
    static let maxFileSize = 8 * 1024 * 1024

    public func discover(in context: DiscoveryContext) async throws -> [DiscoveredHotKey] {
        var found: [DiscoveredHotKey] = []
        let running = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier?.lowercased() })
        for (file, bundleID) in plistFiles(home: context.home) {
            try Task.checkCancellation()
            guard !Self.skippedDomains.contains(bundleID), bundleID != context.ownBundleID,
                  let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize, size < Self.maxFileSize,
                  let data = try? Data(contentsOf: file),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) else { continue }
            let hits = ShortcutFormatDetector.detect(in: plist)
            guard !hits.isEmpty else { continue }
            let owner = context.owners.owner(bundleID: bundleID)
            let shownPath = file.path.replacingOccurrences(of: context.home.path, with: "~")
            let isRunning = running.contains(bundleID.lowercased())
            for hit in hits {
                let scope = Self.likelyScope(of: hit.combo)
                var notes: [String] = []
                if scope == .inApp { notes.append("только ⌘ — вероятно, сочетание внутри приложения") }
                if !isRunning { notes.append("приложение не запущено") }
                let confidence: Confidence = isRunning && scope == .global ? hit.confidence : .heuristic
                found.append(DiscoveredHotKey(combo: hit.combo, owner: owner, method: id, confidence: confidence,
                                              scope: scope, action: hit.keyPath,
                                              source: "\(shownPath) → \(hit.keyPath) [\(hit.format.rawValue)]"
                                                  + (notes.isEmpty ? "" : " · " + notes.joined(separator: ", "))))
            }
        }
        return found
    }

    /// Shortcut libraries (KeyboardShortcuts especially) store in-app customisable shortcuts too.
    /// A bare ⌘+key would break every app's menus if registered globally, so it is treated as in-app.
    static func likelyScope(of combo: KeyCombo) -> HotKeyScope {
        combo.modifiers == [.command] && combo.keyCode != 49 && !KeyCodes.isFunctionKey(combo.keyCode) ? .inApp : .global
    }

    /// (plist URL, owning bundle ID). ByHost files carry a hardware UUID suffix that is stripped.
    func plistFiles(home: URL) -> [(URL, String)] {
        let fm = FileManager.default
        var dirs: [(URL, String?)] = []
        if sandboxContainers {
            let containers = home.appendingPathComponent("Library/Containers")
            for name in (try? fm.contentsOfDirectory(atPath: containers.path)) ?? [] {
                dirs.append((containers.appendingPathComponent("\(name)/Data/Library/Preferences"), name))
            }
        } else {
            dirs.append((home.appendingPathComponent("Library/Preferences"), nil))
            dirs.append((home.appendingPathComponent("Library/Preferences/ByHost"), nil))
        }
        var result: [(URL, String)] = []
        for (dir, containerID) in dirs {
            guard let files = try? fm.contentsOfDirectory(atPath: dir.path) else { continue }
            for file in files where file.hasSuffix(".plist") {
                var domain = String(file.dropLast(6))
                if dir.lastPathComponent == "ByHost", let dot = domain.lastIndex(of: "."),
                   domain[domain.index(after: dot)...].count >= 12 {
                    domain = String(domain[..<dot])
                }
                result.append((dir.appendingPathComponent(file), containerID ?? domain))
            }
        }
        return result
    }
}
