import Foundation

/// BetterTouchTool `.bttpreset` JSON (and a JSON/plist snapshot of the same shape).
///
/// Keyboard triggers are objects whose `BTTTriggerClass` is `BTTTriggerTypeKeyboardShortcut` and whose
/// `BTTShortcutKeyCode` is a real virtual key (`>= 0`; groups use `-1`). Modifiers are Cocoa flags in
/// `BTTShortcutModifierKeys`. Nested actions live in `BTTAdditionalActions` and inherit the enclosing
/// app group. `BT.G` is global; any other bundle id is in-app (BTT only fires it while that app is frontmost).
/// The live SQLite database is not read.
public enum BetterTouchToolParser {
    private static let globalBundle = "BT.G"

    public static func parse(_ root: Any) -> [ParsedConfigHotKey] {
        var found: [ParsedConfigHotKey] = []
        walk(root, appBundleID: nil, appName: nil, into: &found)
        return found
    }

    private static func walk(_ value: Any, appBundleID: String?, appName: String?, into found: inout [ParsedConfigHotKey]) {
        if let array = ConfigFiles.array(value) {
            for item in array { walk(item, appBundleID: appBundleID, appName: appName, into: &found) }
            return
        }
        guard let dict = ConfigFiles.dictionary(value) else { return }
        let bundle = ConfigFiles.string(dict["BTTAppBundleIdentifier"]) ?? appBundleID
        let name = ConfigFiles.string(dict["BTTAppName"]) ?? appName
        if let trigger = trigger(dict, appBundleID: bundle, appName: name) { found.append(trigger) }
        for key in ["BTTPresetContent", "BTTTriggers", "BTTAdditionalActions"] {
            if let child = dict[key] { walk(child, appBundleID: bundle, appName: name, into: &found) }
        }
    }

    private static func trigger(_ dict: [String: Any], appBundleID: String?, appName: String?) -> ParsedConfigHotKey? {
        guard ConfigFiles.string(dict["BTTTriggerClass"]) == "BTTTriggerTypeKeyboardShortcut",
              let keyCode = ConfigFiles.int(dict["BTTShortcutKeyCode"]), keyCode >= 0, keyCode < 128 else { return nil }
        let modifiers = ModifierSet(cocoa: UInt64(ConfigFiles.int(dict["BTTShortcutModifierKeys"]) ?? 0))
        let combo = KeyCombo(keyCode: UInt16(keyCode), modifiers: modifiers)
        guard combo.modifiers.isShortcutLike || KeyCodes.isFunctionKey(combo.keyCode) else { return nil }
        let enabled = ConfigFiles.enabledFlag(in: dict, keys: ["BTTEnabled2", "BTTEnabled"])
        let action = ConfigFiles.string(dict["BTTGestureNotes"])
            ?? ConfigFiles.string(dict["BTTPredefinedActionName"])
            ?? ConfigFiles.string(dict["BTTTriggerTypeDescription"])
            ?? "Сочетание BetterTouchTool"
        let global = appBundleID == nil || appBundleID == globalBundle
        let place = global ? "Global" : (appName ?? appBundleID ?? "app")
        return ParsedConfigHotKey(combo: combo, action: action, enabled: enabled,
                                  source: "\(place) → key \(keyCode)",
                                  scope: global ? .global : .inApp)
    }
}
