import Foundation

/// Hotkeys stored in Raycast JSON or plist exports and settings files.
///
/// Raycast keeps many shortcuts in a private database that this parser does not open. What it does read
/// is any object, anywhere in the tree, that has a `hotkey` or `shortcut` field:
/// - a string (`cmd+shift+k`, `Option-Command-49`), parsed like other textual hotkeys;
/// - an object `{keyCode, modifiers}` where `modifiers` is a Cocoa mask or an array of names,
///   and the key may be `keyCode` or a `key` string.
/// A sibling `name` / `title` / `command` is the action. `enabled: false` keeps the claim but marks it off.
public enum RaycastParser {
    public static func parse(_ root: Any) -> [ParsedConfigHotKey] {
        var found: [ParsedConfigHotKey] = []
        walk(root, into: &found)
        return found
    }

    private static func walk(_ value: Any, into found: inout [ParsedConfigHotKey]) {
        if let dict = ConfigFiles.dictionary(value) {
            if let claim = claim(in: dict) { found.append(claim) }
            for child in dict.values { walk(child, into: &found) }
        } else if let array = ConfigFiles.array(value) {
            for child in array { walk(child, into: &found) }
        }
    }

    private static func claim(in dict: [String: Any]) -> ParsedConfigHotKey? {
        for (key, value) in dict where isHotkeyField(key) {
            guard let combo = combo(from: value) else { continue }
            let action = ConfigFiles.string(dict["name"])
                ?? ConfigFiles.string(dict["title"])
                ?? ConfigFiles.string(dict["command"])
                ?? "Сочетание Raycast"
            return ParsedConfigHotKey(combo: combo, action: action,
                                      enabled: ConfigFiles.enabledFlag(in: dict, keys: ["enabled", "isEnabled"]),
                                      source: key)
        }
        return nil
    }

    private static func isHotkeyField(_ key: String) -> Bool {
        switch key.lowercased() {
        case "hotkey", "shortcut", "globalhotkey", "raycasthotkey": return true
        default: return key.lowercased().hasSuffix("hotkey")
        }
    }

    static func combo(from value: Any) -> KeyCombo? {
        if let text = ConfigFiles.string(value) { return KeyEquivalentParser.parseHotKeyString(text) }
        guard let dict = ConfigFiles.dictionary(value) else { return nil }
        let keyCode = ConfigFiles.int(dict["keyCode"]) ?? ConfigFiles.int(dict["keycode"])
        let named = ConfigFiles.string(dict["key"]).flatMap { KeyEquivalentParser.keyCode(forToken: $0.lowercased()) }
        guard let code = keyCode.map({ UInt16(clamping: $0) }) ?? named, code < 128 else { return nil }
        let modifiers: ModifierSet
        if let mask = ConfigFiles.int(dict["modifiers"]) ?? ConfigFiles.int(dict["modifierFlags"]) {
            modifiers = ModifierSet(cocoa: UInt64(mask))
        } else if let names = ConfigFiles.array(dict["modifiers"])?.compactMap({ ConfigFiles.string($0) }) {
            modifiers = ModifierSet(names: names.map { canonicalModifier($0) })
        } else {
            modifiers = []
        }
        let combo = KeyCombo(keyCode: code, modifiers: modifiers)
        guard combo.modifiers.isShortcutLike || KeyCodes.isFunctionKey(code) else { return nil }
        return combo
    }

    private static func canonicalModifier(_ name: String) -> String {
        switch name.lowercased() {
        case "cmd", "command", "⌘": return "command"
        case "opt", "option", "alt", "⌥": return "option"
        case "ctrl", "control", "⌃": return "control"
        case "shift", "⇧": return "shift"
        case "fn", "function": return "function"
        default: return name.lowercased()
        }
    }
}
