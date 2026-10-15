import Foundation

/// Keyboard Maestro `Keyboard Maestro Macros.plist` (and an exported `.kmmacros` array of groups).
///
/// Hot key triggers store a virtual `KeyCode` and Carbon modifier bits (`⌘ 256`, `⇧ 512`, `⌥ 2048`, `⌃ 4096`).
/// A group whose `Activate` is `Deactivated` / `Disabled`, or a macro with `IsActive` false, is kept and
/// marked disabled. A group with `Targeting` = `Included` fires only while one of its apps is frontmost,
/// so those claims are in-app. Other trigger types (typed strings, MIDI, …) are ignored.
public enum KeyboardMaestroParser {
    public static func parse(_ root: Any) -> [ParsedConfigHotKey] {
        let groups: [Any]
        if let array = ConfigFiles.array(root) {
            groups = array
        } else if let dict = ConfigFiles.dictionary(root) {
            groups = ConfigFiles.array(dict["MacroGroups"]) ?? []
        } else {
            return []
        }
        return groups.flatMap { group in
            guard let group = ConfigFiles.dictionary(group) else { return [ParsedConfigHotKey]() }
            return parseGroup(group)
        }
    }

    private static func parseGroup(_ group: [String: Any]) -> [ParsedConfigHotKey] {
        let groupName = ConfigFiles.string(group["Name"]) ?? "Группа"
        let activate = (ConfigFiles.string(group["Activate"]) ?? "Normal").lowercased()
        let groupEnabled = activate != "deactivated" && activate != "disabled"
            && ConfigFiles.enabledFlag(in: group, keys: ["Enabled"])
        let included = ConfigFiles.string(group["Targeting"])?.caseInsensitiveCompare("Included") == .orderedSame
        let macros = ConfigFiles.array(group["Macros"]) ?? []
        var found: [ParsedConfigHotKey] = []
        for macro in macros {
            guard let macro = ConfigFiles.dictionary(macro) else { continue }
            let macroName = ConfigFiles.string(macro["Name"]) ?? "Макрос"
            let macroEnabled = groupEnabled && ConfigFiles.enabledFlag(in: macro, keys: ["IsActive"])
            let triggers = ConfigFiles.array(macro["Triggers"]) ?? []
            for trigger in triggers {
                guard let trigger = ConfigFiles.dictionary(trigger),
                      ConfigFiles.string(trigger["MacroTriggerType"]) == "HotKey",
                      let keyCode = ConfigFiles.int(trigger["KeyCode"]), keyCode >= 0, keyCode < 128 else { continue }
                let modifiers = ModifierSet(carbon: ConfigFiles.int(trigger["Modifiers"]) ?? 0)
                let combo = KeyCombo(keyCode: UInt16(keyCode), modifiers: modifiers)
                guard combo.modifiers.isShortcutLike || KeyCodes.isFunctionKey(combo.keyCode) else { continue }
                found.append(ParsedConfigHotKey(combo: combo, action: "\(groupName): \(macroName)",
                                                enabled: macroEnabled,
                                                source: "\(groupName) → \(macroName)",
                                                scope: included ? .inApp : .global))
            }
        }
        return found
    }
}
