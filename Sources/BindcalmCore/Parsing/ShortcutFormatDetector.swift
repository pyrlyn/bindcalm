import Foundation

public struct DetectedShortcut: Hashable, Sendable {
    public enum Format: String, Sendable, Codable {
        case masShortcut = "MASShortcut"
        case shortcutRecorder = "ShortcutRecorder"
        case keyboardShortcuts = "KeyboardShortcuts"
        case carbonPair = "keyCode+modifiers"
        case symbolicParameters = "parameters(char,keyCode,flags)"
        case hotKeyString = "hotkey string"
    }

    public var keyPath: String
    public var combo: KeyCombo
    public var format: Format
    public var confidence: Confidence
}

/// Recognises the storage formats popular shortcut libraries use inside preference plists.
/// Pure function over property-list objects so it can be unit-tested without touching disk.
public enum ShortcutFormatDetector {
    public static func detect(in root: Any, maxDepth: Int = 8, limit: Int = 200) -> [DetectedShortcut] {
        var found: [DetectedShortcut] = []
        walk(root, path: "", depth: 0, maxDepth: maxDepth, limit: limit, into: &found)
        return found
    }

    private static func walk(_ value: Any, path: String, depth: Int, maxDepth: Int, limit: Int,
                             into found: inout [DetectedShortcut]) {
        guard depth <= maxDepth, found.count < limit else { return }
        switch value {
        case let dict as [String: Any]:
            if let hit = detectDictionary(dict, path: path) {
                found.append(hit)
                return
            }
            for (key, child) in dict.sorted(by: { $0.key < $1.key }) {
                let childPath = path.isEmpty ? key : "\(path).\(key)"
                if let text = child as? String, let hit = detectString(text, key: key, path: childPath) {
                    found.append(hit)
                } else {
                    walk(child, path: childPath, depth: depth + 1, maxDepth: maxDepth, limit: limit, into: &found)
                }
            }
        case let array as [Any]:
            for (index, child) in array.prefix(500).enumerated() {
                walk(child, path: "\(path)[\(index)]", depth: depth + 1, maxDepth: maxDepth, limit: limit, into: &found)
            }
        case let data as Data:
            // MASShortcut (NSCoding) and some recorders archive into nested binary plists.
            guard data.count < 256 * 1024, data.starts(with: Array("bplist".utf8)) else { return }
            if let nested = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) {
                walk(nested, path: path + "<data>", depth: depth + 1, maxDepth: maxDepth, limit: limit, into: &found)
            }
        default:
            return
        }
    }

    private static func int(_ dict: [String: Any], _ names: [String]) -> Int? {
        for (key, value) in dict where names.contains(key.lowercased()) {
            if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() { return number.intValue }
        }
        return nil
    }

    static func detectDictionary(_ dict: [String: Any], path: String) -> DetectedShortcut? {
        if let code = int(dict, ["carbonkeycode"]), let mods = int(dict, ["carbonmodifiers"]) {
            return make(path, code, ModifierSet(carbon: mods), .keyboardShortcuts, .partial)
        }
        if let code = int(dict, ["keycode"]), let flags = int(dict, ["modifierflags"]) {
            let isRecorder = dict.keys.contains { ["characters", "charactersignoringmodifiers"].contains($0.lowercased()) }
            return make(path, code, ModifierSet(cocoa: UInt64(max(0, flags))),
                        isRecorder ? .shortcutRecorder : .masShortcut, .partial)
        }
        if let code = int(dict, ["keycode", "key_code", "virtualkey"]), let mods = int(dict, ["modifiers", "modifiermask"]) {
            // Ambiguous encoding: Carbon masks fit in 16 bits, Cocoa masks start at bit 17.
            let set = mods >= (1 << 16) ? ModifierSet(cocoa: UInt64(mods)) : ModifierSet(carbon: mods)
            return make(path, code, set, .carbonPair, .heuristic)
        }
        if let params = dict["parameters"] as? [NSNumber], params.count == 3,
           let combo = SymbolicHotKeysParser.comboFromParameters(params.map { $0.intValue }),
           combo.modifiers.isShortcutLike || KeyCodes.isFunctionKey(combo.keyCode) {
            return DetectedShortcut(keyPath: path, combo: combo, format: .symbolicParameters, confidence: .partial)
        }
        return nil
    }

    static func detectString(_ text: String, key: String, path: String) -> DetectedShortcut? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("{"), trimmed.contains("carbonKeyCode"),
           let data = trimmed.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let hit = detectDictionary(json, path: path) {
            return hit
        }
        let lowerKey = key.lowercased()
        guard lowerKey.contains("hotkey") || lowerKey.contains("hot_key") || lowerKey.contains("shortcut")
            || lowerKey.contains("keybinding") || lowerKey.contains("keyequivalent") else { return nil }
        guard let combo = KeyEquivalentParser.parseHotKeyString(trimmed) else { return nil }
        return DetectedShortcut(keyPath: path, combo: combo, format: .hotKeyString, confidence: .heuristic)
    }

    private static func make(_ path: String, _ code: Int, _ mods: ModifierSet, _ format: DetectedShortcut.Format,
                             _ confidence: Confidence) -> DetectedShortcut? {
        guard code >= 0, code < 128, !KeyCodes.modifierKeyCodes.contains(UInt16(code)) else { return nil }
        let combo = KeyCombo(keyCode: UInt16(code), modifiers: mods)
        // An unmodified letter is how "empty" recorders are often persisted; it is not a hotkey.
        guard combo.modifiers.isShortcutLike || KeyCodes.isFunctionKey(combo.keyCode) else { return nil }
        return DetectedShortcut(keyPath: path, combo: combo, format: format, confidence: confidence)
    }
}
