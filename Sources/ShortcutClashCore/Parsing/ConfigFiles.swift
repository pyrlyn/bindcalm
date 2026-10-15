import CoreFoundation
import Foundation

/// One shortcut read from a third-party tool's config file, before it is wrapped as a `DiscoveredHotKey`.
public struct ParsedConfigHotKey: Hashable, Sendable {
    public var combo: KeyCombo
    public var action: String
    public var enabled: Bool
    public var source: String
    public var scope: HotKeyScope

    public init(combo: KeyCombo, action: String, enabled: Bool = true, source: String, scope: HotKeyScope = .global) {
        self.combo = combo
        self.action = action
        self.enabled = enabled
        self.source = source
        self.scope = scope
    }
}

/// Shared file and JSON/plist helpers for the config-file strategies. Parsers themselves stay pure.
enum ConfigFiles {
    static let maxBytes = 8 * 1024 * 1024

    static func data(at url: URL) -> Data? {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? Int.max
        guard size <= maxBytes else { return nil }
        return try? Data(contentsOf: url)
    }

    static func text(at url: URL) -> String? {
        guard let data = data(at: url) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func jsonObject(from data: Data) -> Any? {
        try? JSONSerialization.jsonObject(with: data)
    }

    static func propertyList(from data: Data) -> Any? {
        try? PropertyListSerialization.propertyList(from: data, format: nil)
    }

    static func displayPath(_ url: URL, home: URL) -> String {
        let path = url.path
        let prefix = home.path
        guard path.hasPrefix(prefix) else { return path }
        return "~" + path.dropFirst(prefix.count)
    }

    /// `NSNumber` bridging treats JSON booleans as numbers. Reject those so `1` and `true` stay distinct.
    static func int(_ any: Any?) -> Int? {
        guard let number = any as? NSNumber else { return nil }
        guard CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let value = number.doubleValue
        guard value.rounded() == value, value <= Double(Int.max), value >= Double(Int.min) else { return nil }
        return number.intValue
    }

    static func bool(_ any: Any?) -> Bool? {
        guard let number = any as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
        return number.boolValue
    }

    static func string(_ any: Any?) -> String? { any as? String }

    static func dictionary(_ any: Any?) -> [String: Any]? { any as? [String: Any] }

    static func array(_ any: Any?) -> [Any]? { any as? [Any] }

    /// Config files record a binding the user created, including Shift-only and fn-only chords that the
    /// heuristic scanners reject. F-keys stay claimable after `KeyCombo` strips their implicit fn flag.
    static func accepts(_ combo: KeyCombo) -> Bool {
        !combo.modifiers.isEmpty || KeyCodes.isFunctionKey(combo.keyCode)
    }

    static func enabledFlag(in dict: [String: Any], keys: [String], default defaultValue: Bool = true) -> Bool {
        for key in keys {
            if let flag = bool(dict[key]) { return flag }
            if let number = int(dict[key]) { return number != 0 }
        }
        return defaultValue
    }

    /// Resolves a bundle id for the icon when the app is installed, and keeps a readable name when it is not.
    static func owner(bundleID: String, fallbackName: String, context: DiscoveryContext) -> HotKeyOwner {
        let resolved = context.owners.owner(bundleID: bundleID)
        if resolved.path == nil, resolved.name == bundleID {
            return HotKeyOwner(name: fallbackName, bundleID: bundleID)
        }
        return resolved
    }

    static func files(in directory: URL, extensions: Set<String>, skipDirectoryNames: Set<String>,
                      maxDepth: Int, limit: Int) -> [URL] {
        var found: [URL] = []
        func visit(_ dir: URL, depth: Int) {
            guard depth <= maxDepth, found.count < limit else { return }
            guard let items = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
            ) else { return }
            for item in items where found.count < limit {
                let name = item.lastPathComponent
                let isDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if isDirectory {
                    if skipDirectoryNames.contains(name) { continue }
                    visit(item, depth: depth + 1)
                } else if extensions.contains(item.pathExtension.lowercased()) {
                    found.append(item)
                }
            }
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return []
        }
        visit(directory, depth: 0)
        return found
    }
}
