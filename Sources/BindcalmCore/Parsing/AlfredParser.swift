import Foundation

/// Alfred workflow `info.plist` hotkey triggers, plus the launcher hotkey stored as `{key, mod, string}`.
///
/// `hotkey` / `key` is a virtual key code. `hotmod` / `mod` is a Cocoa modifier mask; Alfred sometimes
/// ORs in device-dependent low bits (Shift+Space is `131720` rather than `131072`), which
/// `ModifierSet(cocoa:)` ignores. An object with no modifiers and an empty `hotstring` is an unassigned
/// trigger and is skipped. Shift-only and fn-only chords are kept: Alfred registered them.
/// A disabled workflow is reported with `enabled = false`.
public enum AlfredParser {
    public static func parseWorkflow(_ plist: [String: Any], workflowName: String? = nil) -> [ParsedConfigHotKey] {
        let name = workflowName ?? ConfigFiles.string(plist["name"]) ?? "Workflow"
        let workflowEnabled = ConfigFiles.bool(plist["disabled"]) != true
        let objects = ConfigFiles.array(plist["objects"]) ?? []
        var found: [ParsedConfigHotKey] = []
        for object in objects {
            guard let object = ConfigFiles.dictionary(object),
                  ConfigFiles.string(object["type"]) == "alfred.workflow.trigger.hotkey",
                  let config = ConfigFiles.dictionary(object["config"]),
                  let claim = hotkey(key: ConfigFiles.int(config["hotkey"]),
                                     modifiers: ConfigFiles.int(config["hotmod"]),
                                     label: ConfigFiles.string(config["hotstring"]),
                                     action: name, enabled: workflowEnabled,
                                     source: "\(name) → hotkey") else { continue }
            found.append(claim)
        }
        return found
    }

    /// Walks a preferences plist for Alfred's `{key, mod, string}` hotkey dictionaries (the main
    /// launcher hotkey lives at `preferences/local/<hash>/hotkey/prefs.plist` under `default`).
    public static func parseHotkeyPreferences(_ root: Any, sourceName: String) -> [ParsedConfigHotKey] {
        var found: [ParsedConfigHotKey] = []
        walk(root, path: sourceName, into: &found)
        return found
    }

    private static func walk(_ value: Any, path: String, into found: inout [ParsedConfigHotKey]) {
        guard let dict = ConfigFiles.dictionary(value) else {
            for item in ConfigFiles.array(value) ?? [] { walk(item, path: path, into: &found) }
            return
        }
        // Only files that are themselves hotkey preferences use this {key, mod, string} shape.
        if path.lowercased().contains("hotkey"),
           let label = ConfigFiles.string(dict["string"]), dict["key"] != nil, dict["mod"] != nil,
           let claim = hotkey(key: ConfigFiles.int(dict["key"]), modifiers: ConfigFiles.int(dict["mod"]),
                              label: label, action: "Main Alfred hotkey",
                              enabled: true, source: path) {
            found.append(claim)
            return
        }
        for (key, child) in dict where child is [String: Any] || child is [Any] {
            walk(child, path: "\(path) → \(key)", into: &found)
        }
    }

    private static func hotkey(key: Int?, modifiers: Int?, label: String?, action: String,
                               enabled: Bool, source: String) -> ParsedConfigHotKey? {
        guard let key, let modifiers, key >= 0, key < 128 else { return nil }
        let text = label?.trimmingCharacters(in: .whitespaces) ?? ""
        if modifiers == 0, text.isEmpty { return nil }
        let combo = KeyCombo(keyCode: UInt16(key), modifiers: ModifierSet(cocoa: UInt64(modifiers)))
        guard ConfigFiles.accepts(combo) else { return nil }
        return ParsedConfigHotKey(combo: combo, action: action, enabled: enabled, source: source)
    }
}
