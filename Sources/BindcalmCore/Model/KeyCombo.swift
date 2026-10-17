import Foundation

/// Modifier keys, independent of the encoding a particular API uses.
public struct ModifierSet: OptionSet, Hashable, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let control = ModifierSet(rawValue: 1 << 0)
    public static let option = ModifierSet(rawValue: 1 << 1)
    public static let shift = ModifierSet(rawValue: 1 << 2)
    public static let command = ModifierSet(rawValue: 1 << 3)
    public static let function = ModifierSet(rawValue: 1 << 4)

    public static let hyper: ModifierSet = [.control, .option, .shift, .command]

    /// Carbon `EventModifiers` (cmdKey = 0x100, shiftKey = 0x200, optionKey = 0x800, controlKey = 0x1000).
    public init(carbon: Int) {
        var set: ModifierSet = []
        if carbon & 0x100 != 0 { set.insert(.command) }
        if carbon & 0x200 != 0 { set.insert(.shift) }
        if carbon & 0x800 != 0 { set.insert(.option) }
        if carbon & 0x1000 != 0 { set.insert(.control) }
        self = set
    }

    public var carbonFlags: UInt32 {
        var value: UInt32 = 0
        if contains(.command) { value |= 0x100 }
        if contains(.shift) { value |= 0x200 }
        if contains(.option) { value |= 0x800 }
        if contains(.control) { value |= 0x1000 }
        return value
    }

    /// Cocoa `NSEvent.ModifierFlags` / `CGEventFlags` raw values, also used by the symbolic hotkeys plist.
    public init(cocoa: UInt64) {
        var set: ModifierSet = []
        if cocoa & (1 << 17) != 0 { set.insert(.shift) }
        if cocoa & (1 << 18) != 0 { set.insert(.control) }
        if cocoa & (1 << 19) != 0 { set.insert(.option) }
        if cocoa & (1 << 20) != 0 { set.insert(.command) }
        if cocoa & (1 << 23) != 0 { set.insert(.function) }
        self = set
    }

    public var cocoaFlags: UInt64 {
        var value: UInt64 = 0
        if contains(.shift) { value |= 1 << 17 }
        if contains(.control) { value |= 1 << 18 }
        if contains(.option) { value |= 1 << 19 }
        if contains(.command) { value |= 1 << 20 }
        if contains(.function) { value |= 1 << 23 }
        return value
    }

    /// `kAXMenuItemCmdModifiersAttribute`: Command is implied unless the "no command" bit (8) is set.
    public init(axMenuModifiers: Int) {
        var set: ModifierSet = []
        if axMenuModifiers & 1 != 0 { set.insert(.shift) }
        if axMenuModifiers & 2 != 0 { set.insert(.option) }
        if axMenuModifiers & 4 != 0 { set.insert(.control) }
        if axMenuModifiers & 8 == 0 { set.insert(.command) }
        self = set
    }

    /// Apple's canonical display order: fn ⌃ ⌥ ⇧ ⌘.
    public var symbols: String {
        var text = ""
        if contains(.function) { text += "fn " }
        if contains(.control) { text += "⌃" }
        if contains(.option) { text += "⌥" }
        if contains(.shift) { text += "⇧" }
        if contains(.command) { text += "⌘" }
        return text
    }

    public var names: [String] {
        var list: [String] = []
        if contains(.function) { list.append("function") }
        if contains(.control) { list.append("control") }
        if contains(.option) { list.append("option") }
        if contains(.shift) { list.append("shift") }
        if contains(.command) { list.append("command") }
        return list
    }

    public init(names: [String]) {
        var set: ModifierSet = []
        for name in names {
            switch name {
            case "function": set.insert(.function)
            case "control": set.insert(.control)
            case "option": set.insert(.option)
            case "shift": set.insert(.shift)
            case "command": set.insert(.command)
            default: break
            }
        }
        self = set
    }

    /// Modifiers that make a key press a "shortcut" rather than typing (Shift alone only changes case).
    public var isShortcutLike: Bool {
        !intersection([.command, .control, .option]).isEmpty
    }
}

/// A physical key combination: virtual key code (kVK_*) plus modifiers.
/// Normalising on key codes (not characters) is what makes owners comparable across APIs and layouts.
public struct KeyCombo: Hashable, Comparable, Sendable, Codable, Identifiable {
    public let keyCode: UInt16
    public let modifiers: ModifierSet

    public init(keyCode: UInt16, modifiers: ModifierSet) {
        self.keyCode = keyCode
        var mods = modifiers
        // Cocoa and the symbolic hotkeys plist add the fn flag to arrows and F-keys implicitly;
        // keeping it would split one physical combo into two groups.
        if KeyCodes.impliesFunctionFlag(keyCode) { mods.remove(.function) }
        self.modifiers = mods
    }

    public var id: String { "\(modifiers.rawValue)-\(keyCode)" }
    public var keyName: String { KeyCodes.name(for: keyCode) }
    public var display: String { modifiers.symbols + keyName }

    public static func < (lhs: KeyCombo, rhs: KeyCombo) -> Bool {
        if lhs.keyName != rhs.keyName { return lhs.keyName < rhs.keyName }
        return lhs.modifiers.rawValue < rhs.modifiers.rawValue
    }

    private enum CodingKeys: String, CodingKey { case keyCode, modifiers, display }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(keyCode: try c.decode(UInt16.self, forKey: .keyCode),
                  modifiers: ModifierSet(names: try c.decode([String].self, forKey: .modifiers)))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(keyCode, forKey: .keyCode)
        try c.encode(modifiers.names, forKey: .modifiers)
        try c.encode(display, forKey: .display)
    }
}

/// Virtual key code tables for the ANSI (US) physical layout.
public enum KeyCodes {
    public static let names: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        10: "§", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7",
        27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
        36: "↩", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
        45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Пробел", 50: "`", 51: "⌫", 53: "⎋",
        54: "Правый ⌘", 55: "⌘", 56: "⇧", 57: "⇪", 58: "⌥", 59: "⌃", 60: "Правый ⇧",
        61: "Правый ⌥", 62: "Правый ⌃", 63: "fn/🌐",
        64: "F17", 65: "Num .", 67: "Num *", 69: "Num +", 71: "⌧", 72: "Громкость+",
        73: "Громкость−", 74: "Без звука", 75: "Num /", 76: "⌤", 78: "Num -", 79: "F18",
        80: "F19", 81: "Num =", 82: "Num 0", 83: "Num 1", 84: "Num 2", 85: "Num 3",
        86: "Num 4", 87: "Num 5", 88: "Num 6", 89: "Num 7", 90: "F20", 91: "Num 8",
        92: "Num 9", 93: "¥", 94: "_", 95: "Num ,", 96: "F5", 97: "F6", 98: "F7", 99: "F3",
        100: "F8", 101: "F9", 102: "英数", 103: "F11", 104: "かな", 105: "F13", 106: "F16",
        107: "F14", 109: "F10", 110: "Меню", 111: "F12", 113: "F15", 114: "Help", 115: "↖",
        116: "⇞", 117: "⌦", 118: "F4", 119: "↘", 120: "F2", 121: "⇟", 122: "F1",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    public static func name(for keyCode: UInt16) -> String {
        names[keyCode] ?? "Key \(keyCode)"
    }

    /// Unshifted characters of the ANSI US layout.
    public static let usCharacters: [Character: UInt16] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "§": 10, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
        "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26,
        "-": 27, "8": 28, "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35,
        "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44,
        "n": 45, "m": 46, ".": 47, "`": 50, " ": 49,
    ]

    /// Characters that the US layout produces only with Shift.
    public static let usShiftedCharacters: [Character: UInt16] = [
        "!": 18, "@": 19, "#": 20, "$": 21, "%": 23, "^": 22, "&": 26, "*": 28, "(": 25,
        ")": 29, "_": 27, "+": 24, "{": 33, "}": 30, "|": 42, ":": 41, "\"": 39, "<": 43,
        ">": 47, "?": 44, "~": 50, "±": 10,
    ]

    public static let functionKeys: [UInt16] = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80, 90]

    public static func functionKey(_ number: Int) -> UInt16? {
        guard number >= 1, number <= functionKeys.count else { return nil }
        return functionKeys[number - 1]
    }

    public static let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]

    public static func isFunctionKey(_ keyCode: UInt16) -> Bool { functionKeys.contains(keyCode) }

    /// Keys for which Cocoa reports the fn flag even when fn is not pressed.
    public static func impliesFunctionFlag(_ keyCode: UInt16) -> Bool {
        isFunctionKey(keyCode) || [114, 115, 116, 117, 119, 121, 123, 124, 125, 126].contains(keyCode)
    }

    /// Key codes whose label is a printable character on ANSI keyboards; used for layout tables.
    public static var printableKeyCodes: [UInt16] {
        usCharacters.values.filter { $0 != 49 }.sorted()
    }

    /// Named non-character keys accepted in textual hotkey descriptions.
    public static let namedKeys: [String: UInt16] = [
        "space": 49, "spacebar": 49, "return": 36, "enter": 36, "tab": 48, "esc": 53, "escape": 53,
        "delete": 51, "backspace": 51, "forwarddelete": 117, "del": 117, "home": 115, "end": 119,
        "pageup": 116, "pagedown": 121, "left": 123, "right": 124, "down": 125, "up": 126,
        "leftarrow": 123, "rightarrow": 124, "downarrow": 125, "uparrow": 126, "help": 114,
        "grave": 50, "backtick": 50, "minus": 27, "equal": 24, "comma": 43, "period": 47,
        "slash": 44, "backslash": 42, "semicolon": 41, "quote": 39, "leftbracket": 33,
        "rightbracket": 30, "capslock": 57,
        "␣": 49, "↩": 36, "⇥": 48, "⎋": 53, "⌫": 51, "⌦": 117, "←": 123, "→": 124, "↓": 125, "↑": 126,
    ]
}
