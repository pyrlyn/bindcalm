import Foundation

/// skhd config (`~/.config/skhd/skhdrc` or `~/.skhdrc`).
///
/// Grammar, abbreviated from the skhd README: `modes < modifiers - key [: command | ; mode | [ process map ]`.
/// `hyper` is ⌃⌥⇧⌘ and `meh` is ⌃⌥⇧. `delete` is forward delete; `backspace` is delete.
/// Hex keycodes (`0x21`) are virtual key codes. `.blacklist` / `.unlisted` blocks and mode declarations
/// (`:: name`) are skipped. A binding that only switches mode or passes the key through (`->`) is still a claim.
public enum SkhdParser {
    public static func parse(_ text: String) -> [ParsedConfigHotKey] {
        let lines = logicalLines(text)
        var found: [ParsedConfigHotKey] = []
        var bracketDepth = 0
        for line in lines {
            if bracketDepth > 0 {
                bracketDepth += bracketBalance(line)
                if bracketDepth < 0 { bracketDepth = 0 }
                continue
            }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("::") || trimmed.hasPrefix(".") {
                bracketDepth = max(0, bracketBalance(trimmed))
                continue
            }
            if let hotkey = parseLine(trimmed) { found.append(hotkey) }
            let balance = bracketBalance(trimmed)
            if balance > 0 { bracketDepth = balance }
        }
        return found
    }

    static func parseLine(_ line: String) -> ParsedConfigHotKey? {
        var body = stripModes(line)
        let passthrough = body.contains("->")
        body = body.replacingOccurrences(of: "->", with: "")
        guard let separator = modifierKeySplit(body) else { return nil }
        let modifierPart = body[..<separator.lowerBound].trimmingCharacters(in: .whitespaces)
        let rest = body[separator.upperBound...].trimmingCharacters(in: .whitespaces)
        let (keyToken, action) = splitKeyAndAction(rest)
        guard let keyCode = keyCode(for: keyToken), let modifiers = modifiers(from: modifierPart) else { return nil }
        let combo = KeyCombo(keyCode: keyCode, modifiers: modifiers)
        guard ConfigFiles.accepts(combo) else { return nil }
        var label = action.isEmpty ? "skhd shortcut" : action
        if passthrough { label = "passes the key through · \(label)" }
        return ParsedConfigHotKey(combo: combo, action: String(label.prefix(160)),
                                  source: "\(modifierPart) - \(keyToken)")
    }

    /// Split on ` - ` before the action (`:`, `;` or `[`) so a shell command like `open -a` is not a second key.
    private static func modifierKeySplit(_ body: String) -> Range<String.Index>? {
        let limit = body.rangeOfCharacter(from: CharacterSet(charactersIn: ":;["))?.lowerBound ?? body.endIndex
        var search = body.startIndex
        var match: Range<String.Index>?
        while let range = body.range(of: " - ", range: search..<limit) {
            let keySide = body[range.upperBound..<limit].trimmingCharacters(in: .whitespaces)
            let token = keySide.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
            if keyCode(for: token) != nil { match = range }
            search = range.upperBound
        }
        return match
    }

    private static func splitKeyAndAction(_ rest: String) -> (String, String) {
        let separators = CharacterSet(charactersIn: ":;[")
        if let range = rest.rangeOfCharacter(from: separators) {
            let key = rest[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
            var action = rest[range.upperBound...].trimmingCharacters(in: .whitespaces)
            if rest[range.lowerBound] == ";" { action = "mode \(action)".trimmingCharacters(in: .whitespaces) }
            if rest[range.lowerBound] == "[" { action = action.isEmpty ? "per app" : action }
            return (key, action)
        }
        return (rest.trimmingCharacters(in: .whitespaces), "")
    }

    /// `main, focus < cmd - a` selects modes. A `<` after the key belongs to the command and is left alone.
    private static func stripModes(_ line: String) -> String {
        guard let angle = line.firstIndex(of: "<") else { return line.trimmingCharacters(in: .whitespaces) }
        let prefix = line[..<angle]
        if prefix.contains(" - ") { return line.trimmingCharacters(in: .whitespaces) }
        let names = prefix.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let identifier = try? NSRegularExpression(pattern: "^[A-Za-z_][A-Za-z0-9_-]*$")
        guard !names.isEmpty, names.allSatisfy({ name in
            let text = String(name)
            let range = NSRange(text.startIndex..., in: text)
            return identifier?.firstMatch(in: text, range: range) != nil
        }) else { return line.trimmingCharacters(in: .whitespaces) }
        return line[line.index(after: angle)...].trimmingCharacters(in: .whitespaces)
    }

    private static func modifiers(from text: String) -> ModifierSet? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return [] }
        var set: ModifierSet = []
        for raw in trimmed.split(separator: "+") {
            let token = raw.trimmingCharacters(in: .whitespaces).lowercased()
            guard !token.isEmpty else { continue }
            switch token {
            case "hyper": set.formUnion(.hyper)
            case "meh": set.formUnion([.control, .option, .shift])
            case "fn": set.insert(.function)
            case "cmd", "lcmd", "rcmd": set.insert(.command)
            case "shift", "lshift", "rshift": set.insert(.shift)
            case "alt", "lalt", "ralt", "opt", "option": set.insert(.option)
            case "ctrl", "lctrl", "rctrl", "control": set.insert(.control)
            default: return nil
            }
        }
        return set
    }

    static func keyCode(for token: String) -> UInt16? {
        let lower = token.lowercased()
        if lower.hasPrefix("0x"), let value = UInt16(lower.dropFirst(2), radix: 16), value < 128 { return value }
        switch lower {
        case "delete": return 117
        case "backspace": return 51
        default: return KeyEquivalentParser.keyCode(forToken: lower)
        }
    }

    private static func logicalLines(_ text: String) -> [String] {
        var lines: [String] = []
        var pending = ""
        for raw in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            let stripped = stripComment(String(raw))
            let continued = stripped.hasSuffix("\\")
            let piece = continued ? String(stripped.dropLast()) : stripped
            pending += piece
            if continued { continue }
            lines.append(pending)
            pending = ""
        }
        if !pending.isEmpty { lines.append(pending) }
        return lines
    }

    private static func stripComment(_ line: String) -> String {
        guard let hash = line.firstIndex(of: "#") else { return line }
        return String(line[..<hash])
    }

    private static func bracketBalance(_ line: String) -> Int {
        line.reduce(0) { $0 + ($1 == "[" ? 1 : $1 == "]" ? -1 : 0) }
    }
}
