import Foundation

/// Karabiner-Elements `karabiner.json` (complex modifications of the selected profile).
///
/// A manipulator is reported when its `from.key_code` is held with a shortcut modifier or is an F-key.
/// Bare key-to-key remaps (simple modifications, caps lock → escape) are not shortcut claims.
/// Rules in profiles other than the selected one are inactive. When no profile is marked selected,
/// the first profile is used. Runtime `conditions` are not evaluated.
public enum KarabinerParser {
    public static func parse(_ root: Any) -> [ParsedConfigHotKey] {
        guard let profiles = ConfigFiles.array(ConfigFiles.dictionary(root)?["profiles"]), !profiles.isEmpty else { return [] }
        let dicts = profiles.compactMap { ConfigFiles.dictionary($0) }
        let selected = dicts.filter { ConfigFiles.bool($0["selected"]) == true }
        let active = selected.isEmpty ? Array(dicts.prefix(1)) : selected
        return active.flatMap { parseProfile($0) }
    }

    private static func parseProfile(_ profile: [String: Any]) -> [ParsedConfigHotKey] {
        let profileName = ConfigFiles.string(profile["name"]) ?? "profile"
        let rules = ConfigFiles.array(ConfigFiles.dictionary(profile["complex_modifications"])?["rules"]) ?? []
        var found: [ParsedConfigHotKey] = []
        for rule in rules {
            guard let rule = ConfigFiles.dictionary(rule) else { continue }
            let description = ConfigFiles.string(rule["description"]) ?? "Сложное правило"
            let manipulators = ConfigFiles.array(rule["manipulators"]) ?? []
            for manipulator in manipulators {
                guard let manipulator = ConfigFiles.dictionary(manipulator) else { continue }
                if let type = ConfigFiles.string(manipulator["type"]), type != "basic" { continue }
                guard let from = ConfigFiles.dictionary(manipulator["from"]),
                      let keyName = ConfigFiles.string(from["key_code"]),
                      let keyCode = keyCode(for: keyName) else { continue }
                let modifiers = modifiers(from: from["modifiers"])
                let combo = KeyCombo(keyCode: keyCode, modifiers: modifiers)
                guard combo.modifiers.isShortcutLike || KeyCodes.isFunctionKey(keyCode) else { continue }
                found.append(ParsedConfigHotKey(combo: combo, action: description,
                                                source: "\(profileName) → \(description) → \(keyName)"))
            }
        }
        return found
    }

    /// `modifiers` is either `{mandatory, optional}` or a plain array. Only mandatory modifiers form the combo.
    static func modifiers(from raw: Any?) -> ModifierSet {
        let names: [String]
        if let dict = ConfigFiles.dictionary(raw) {
            names = stringList(dict["mandatory"])
        } else {
            names = stringList(raw)
        }
        var set: ModifierSet = []
        for name in names {
            switch name.lowercased() {
            case "command", "left_command", "right_command": set.insert(.command)
            case "shift", "left_shift", "right_shift": set.insert(.shift)
            case "option", "left_option", "right_option", "alt", "left_alt", "right_alt": set.insert(.option)
            case "control", "left_control", "right_control": set.insert(.control)
            case "fn": set.insert(.function)
            default: break
            }
        }
        return set
    }

    private static func stringList(_ raw: Any?) -> [String] {
        if let one = ConfigFiles.string(raw) { return [one] }
        return ConfigFiles.array(raw)?.compactMap { ConfigFiles.string($0) } ?? []
    }

    static func keyCode(for name: String) -> UInt16? {
        let lower = name.lowercased()
        if let code = keyCodes[lower] { return code }
        if lower.hasPrefix("f"), let number = Int(lower.dropFirst()) { return KeyCodes.functionKey(number) }
        if lower.count == 1, let character = lower.first { return KeyCodes.usCharacters[character] }
        return nil
    }

    /// Karabiner's `key_code` names that are not a single ANSI character. Letters and digits fall through
    /// to the US table (`a` → 0, `1` → 18).
    private static let keyCodes: [String: UInt16] = [
        "return_or_enter": 36, "escape": 53, "delete_or_backspace": 51, "delete_forward": 117,
        "tab": 48, "spacebar": 49, "hyphen": 27, "equal_sign": 24, "open_bracket": 33,
        "close_bracket": 30, "backslash": 42, "non_us_pound": 10, "semicolon": 41, "quote": 39,
        "grave_accent_and_tilde": 50, "comma": 43, "period": 47, "slash": 44, "caps_lock": 57,
        "up_arrow": 126, "down_arrow": 125, "left_arrow": 123, "right_arrow": 124,
        "page_up": 116, "page_down": 121, "home": 115, "end": 119, "help": 114,
        "keypad_num_lock": 71, "keypad_slash": 75, "keypad_asterisk": 67, "keypad_hyphen": 78,
        "keypad_plus": 69, "keypad_enter": 76, "keypad_1": 83, "keypad_2": 84, "keypad_3": 85,
        "keypad_4": 86, "keypad_5": 87, "keypad_6": 88, "keypad_7": 89, "keypad_8": 91,
        "keypad_9": 92, "keypad_0": 82, "keypad_period": 65, "keypad_equal_sign": 81,
        "application": 110,
    ]
}
