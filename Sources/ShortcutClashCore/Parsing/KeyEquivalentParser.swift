import Foundation

/// Converts the many textual/character shortcut notations macOS uses into `KeyCombo`.
public enum KeyEquivalentParser {
    /// NSEvent function-key private-use code points (NSUpArrowFunctionKey = 0xF700 ...).
    static let functionKeyScalars: [UInt32: UInt16] = {
        var map: [UInt32: UInt16] = [0xF700: 126, 0xF701: 125, 0xF702: 123, 0xF703: 124,
                                     0xF728: 117, 0xF729: 115, 0xF72B: 119, 0xF72C: 116, 0xF72D: 121,
                                     0xF739: 71, 0xF746: 114]
        for n in 1...20 { if let code = KeyCodes.functionKey(n) { map[0xF703 + UInt32(n)] = code } }
        return map
    }()

    static let controlScalars: [UInt32: UInt16] = [
        0x03: 76, 0x0D: 36, 0x0A: 36, 0x09: 48, 0x19: 48, 0x1B: 53, 0x08: 51, 0x7F: 51, 0x20: 49,
    ]

    static let keypadDigits: [Character: UInt16] = [
        "0": 82, "1": 83, "2": 84, "3": 85, "4": 86, "5": 87, "6": 88, "7": 89, "8": 91, "9": 92,
        ".": 65, "*": 67, "+": 69, "/": 75, "-": 78, "=": 81,
    ]

    /// Maps a key-equivalent character to a combo.
    /// - Parameter uppercaseImpliesShift: Cocoa key equivalents ("K" == ⇧K) say yes; AX menu chars say no,
    ///   because AX always reports the uppercase glyph and carries Shift separately.
    public static func combo(forCharacter text: String, modifiers: ModifierSet, uppercaseImpliesShift: Bool,
                             keypad: Bool = false, layouts: LayoutSnapshot = .empty) -> KeyCombo? {
        guard let char = text.first, text.count == 1, let scalar = char.unicodeScalars.first else { return nil }
        var mods = modifiers
        if keypad, let code = keypadDigits[char] { return KeyCombo(keyCode: code, modifiers: mods) }
        if let code = functionKeyScalars[scalar.value] { return KeyCombo(keyCode: code, modifiers: mods) }
        if let code = controlScalars[scalar.value] { return KeyCombo(keyCode: code, modifiers: mods) }
        let lower = Character(String(char).lowercased())
        if let code = KeyCodes.usCharacters[lower] {
            if uppercaseImpliesShift, char.isUppercase { mods.insert(.shift) }
            return KeyCombo(keyCode: code, modifiers: mods)
        }
        if let code = KeyCodes.usShiftedCharacters[char] {
            mods.insert(.shift)
            return KeyCombo(keyCode: code, modifiers: mods)
        }
        if let hit = layouts.keyCode(for: String(char)) {
            if hit.shift || (uppercaseImpliesShift && char.isUppercase) { mods.insert(.shift) }
            return KeyCombo(keyCode: hit.keyCode, modifiers: mods)
        }
        return nil
    }

    /// Cocoa key-equivalent notation used by NSUserKeyEquivalents and the pbs services status:
    /// `@` ⌘, `$` ⇧, `~` ⌥, `^` ⌃, `#` keypad, followed by exactly one character.
    public static func parseUserKeyEquivalent(_ raw: String, layouts: LayoutSnapshot = .empty) -> KeyCombo? {
        var mods: ModifierSet = []
        var keypad = false
        var rest = Substring(raw)
        while let first = rest.first, rest.count > 1, "@$~^#".contains(first) {
            switch first {
            case "@": mods.insert(.command)
            case "$": mods.insert(.shift)
            case "~": mods.insert(.option)
            case "^": mods.insert(.control)
            default: keypad = true
            }
            rest = rest.dropFirst()
        }
        guard rest.count == 1 else { return nil }
        return combo(forCharacter: String(rest), modifiers: mods, uppercaseImpliesShift: true, keypad: keypad, layouts: layouts)
    }

    /// Carbon menu glyph codes reported by `kAXMenuItemCmdGlyphAttribute` (Menus.h `kMenu*Glyph`).
    public static func keyCode(forMenuGlyph glyph: Int) -> UInt16? {
        switch glyph {
        case 0x02: return 48
        case 0x04: return 76
        case 0x09: return 49
        case 0x0A: return 117
        case 0x0B, 0x0C, 0x0D: return 36
        case 0x17: return 51
        case 0x1B: return 53
        case 0x1C: return 71
        case 0x62: return 116
        case 0x64: return 123
        case 0x65: return 124
        case 0x66: return 115
        case 0x67: return 114
        case 0x68: return 126
        case 0x69: return 119
        case 0x6A: return 125
        case 0x6B: return 121
        case 0x6F...0x7A: return KeyCodes.functionKey(glyph - 0x6F + 1)
        case 0x87...0x89: return KeyCodes.functionKey(glyph - 0x87 + 13)
        case 0x8F...0x92: return KeyCodes.functionKey(glyph - 0x8F + 16)
        default: return nil
        }
    }

    static let modifierWords: [String: ModifierSet] = [
        "cmd": .command, "command": .command, "⌘": .command, "super": .command, "meta": .command,
        "shift": .shift, "⇧": .shift,
        "alt": .option, "opt": .option, "option": .option, "⌥": .option,
        "ctrl": .control, "control": .control, "ctl": .control, "⌃": .control,
        "fn": .function, "function": .function,
        "hyper": .hyper,
    ]

    /// Free-form hotkey strings found in third-party preferences:
    /// Raycast-style "Option-Command-49", "cmd+shift+k", "ctrl-alt-space", "⌘⇧K".
    /// Returns nil for anything that is not clearly a shortcut, to keep the heuristic scan quiet.
    public static func parseHotKeyString(_ raw: String) -> KeyCombo? {
        let text = raw.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, text.count <= 40 else { return nil }

        var mods: ModifierSet = []
        var body = Substring(text)
        while let first = body.first, let mod = modifierWords[String(first)] {
            mods.formUnion(mod)
            body = body.dropFirst()
        }
        if !mods.isEmpty, !body.isEmpty, !body.contains("+"), !body.contains("-") {
            if let code = keyCode(forToken: String(body)) {
                return accept(KeyCombo(keyCode: code, modifiers: mods))
            }
            return nil
        }

        let tokens = text.split(whereSeparator: { "+- ".contains($0) }).map { String($0) }
        guard tokens.count >= 2, let last = tokens.last else { return nil }
        mods = []
        for token in tokens.dropLast() {
            guard let mod = modifierWords[token.lowercased()] else { return nil }
            mods.formUnion(mod)
        }
        let code: UInt16?
        if let number = Int(last), number >= 0, number < 128, last.count > 1 || tokens.first.map({ $0.first?.isUppercase ?? false }) == true {
            // Raycast stores the virtual key code itself ("Command-49").
            code = UInt16(number)
        } else {
            code = keyCode(forToken: last)
        }
        guard let code else { return nil }
        return accept(KeyCombo(keyCode: code, modifiers: mods))
    }

    static func keyCode(forToken token: String) -> UInt16? {
        let lower = token.lowercased()
        if let code = KeyCodes.namedKeys[lower] { return code }
        if lower.count == 1, let char = lower.first, let code = KeyCodes.usCharacters[char] { return code }
        if lower.hasPrefix("f"), let n = Int(lower.dropFirst()) { return KeyCodes.functionKey(n) }
        return nil
    }

    static func accept(_ combo: KeyCombo) -> KeyCombo? {
        combo.modifiers.isShortcutLike || KeyCodes.isFunctionKey(combo.keyCode) ? combo : nil
    }
}
