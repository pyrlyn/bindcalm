import Foundation

/// Hammerspoon `hs.hotkey.bind` / `hs.hotkey.new` calls with a literal modifier table and a literal key.
///
/// Bindings built from variables are invisible. Line comments (`--`) and long comments (`--[[ ... ]]`)
/// are removed before matching, so a sample in a comment is not reported. The optional string after the
/// key (the message argument) becomes the action.
public enum HammerspoonParser {
    public static func parse(_ source: String) -> [ParsedConfigHotKey] {
        let text = stripComments(source)
        let pattern = "hs\\.hotkey\\.(?:bind|new)\\s*\\(\\s*\\{([^}]*)\\}\\s*,\\s*(['\"])(.*?)\\2(?:\\s*,\\s*(['\"])(.*?)\\4)?"
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }
        let range = NSRange(text.startIndex..., in: text)
        var found: [ParsedConfigHotKey] = []
        for match in expression.matches(in: text, range: range) {
            guard let modifierRange = Range(match.range(at: 1), in: text),
                  let keyRange = Range(match.range(at: 3), in: text) else { continue }
            let modifiers = modifiers(from: String(text[modifierRange]))
            guard let keyCode = keyCode(for: String(text[keyRange])) else { continue }
            let combo = KeyCombo(keyCode: keyCode, modifiers: modifiers)
            guard combo.modifiers.isShortcutLike || KeyCodes.isFunctionKey(keyCode) else { continue }
            let message: String
            if match.range(at: 5).location != NSNotFound, let messageRange = Range(match.range(at: 5), in: text) {
                message = String(text[messageRange])
            } else {
                message = "Сочетание Hammerspoon"
            }
            found.append(ParsedConfigHotKey(combo: combo, action: String(message.prefix(160)),
                                            source: "hs.hotkey → \(String(text[keyRange]))"))
        }
        return found
    }

    static func modifiers(from table: String) -> ModifierSet {
        var set: ModifierSet = []
        for raw in table.split(separator: ",") {
            let token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                .lowercased()
            switch token {
            case "cmd", "command", "⌘": set.insert(.command)
            case "alt", "option", "opt": set.insert(.option)
            case "shift": set.insert(.shift)
            case "ctrl", "control": set.insert(.control)
            case "fn": set.insert(.function)
            default: break
            }
        }
        return set
    }

    static func keyCode(for token: String) -> UInt16? {
        let lower = token.lowercased()
        if let code = keypad[lower] { return code }
        return KeyEquivalentParser.keyCode(forToken: lower)
    }

    private static let keypad: [String: UInt16] = [
        "pad0": 82, "pad1": 83, "pad2": 84, "pad3": 85, "pad4": 86, "pad5": 87, "pad6": 88,
        "pad7": 89, "pad8": 91, "pad9": 92, "padclear": 71, "padenter": 76, "padplus": 69,
        "padminus": 78, "padequal": 81, "pad*": 67, "pad/": 75, "pad.": 65,
    ]

    static func stripComments(_ source: String) -> String {
        var result = ""
        var index = source.startIndex
        while index < source.endIndex {
            if source[index...].hasPrefix("--[[") {
                let start = source.index(index, offsetBy: 4)
                if let end = source.range(of: "]]", range: start..<source.endIndex) {
                    index = end.upperBound
                    continue
                }
            }
            if source[index...].hasPrefix("--") {
                if let newline = source[index...].firstIndex(of: "\n") {
                    index = newline
                    continue
                }
                break
            }
            result.append(source[index])
            index = source.index(after: index)
        }
        return result
    }
}
