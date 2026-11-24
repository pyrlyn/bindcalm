import Foundation

public struct SymbolicHotKeyEntry: Hashable, Sendable {
    public var id: Int
    public var enabled: Bool
    public var combo: KeyCombo?
}

/// `com.apple.symbolichotkeys` → `AppleSymbolicHotKeys`:
/// `{ "64" = { enabled = 1; value = { parameters = (32, 49, 1048576); type = standard; }; }; }`
/// parameters = (character or 65535, virtual key code or 65535, Cocoa modifier flags).
public enum SymbolicHotKeysParser {
    public static func parse(_ root: [String: Any]) -> [SymbolicHotKeyEntry] {
        var entries: [SymbolicHotKeyEntry] = []
        for (key, raw) in root {
            guard let id = Int(key), let dict = raw as? [String: Any] else { continue }
            let enabled = (dict["enabled"] as? NSNumber)?.boolValue ?? false
            var combo: KeyCombo?
            if let value = dict["value"] as? [String: Any],
               (value["type"] as? String ?? "standard") == "standard",
               let params = value["parameters"] as? [NSNumber], params.count >= 3 {
                combo = comboFromParameters(params.map { $0.intValue })
            }
            entries.append(SymbolicHotKeyEntry(id: id, enabled: enabled, combo: combo))
        }
        return entries.sorted { $0.id < $1.id }
    }

    public static func comboFromParameters(_ params: [Int]) -> KeyCombo? {
        guard params.count >= 3 else { return nil }
        let keyCode = params[1]
        guard keyCode >= 0, keyCode < 0xFFFF else { return nil }
        return KeyCombo(keyCode: UInt16(keyCode), modifiers: ModifierSet(cocoa: UInt64(max(0, params[2]))))
    }

    /// Community-documented IDs (no official Apple list exists). Unknown IDs are shown as "#id".
    public static let names: [Int: String] = [
        7: "Focus menu bar", 8: "Focus Dock", 9: "Focus active/next window",
        10: "Focus window toolbar", 11: "Focus floating window",
        12: "Toggle full keyboard access", 13: "Change Tab behavior",
        15: "Zoom: on/off", 17: "Zoom: zoom in", 19: "Zoom: zoom out",
        21: "Invert colors", 23: "Smooth images when zoomed",
        25: "Increase contrast", 26: "Decrease contrast",
        27: "Focus next window", 28: "Screenshot to file",
        29: "Screenshot to clipboard", 30: "Selection screenshot to file", 31: "Selection screenshot to clipboard",
        32: "Mission Control", 33: "Application windows", 34: "Mission Control (slow)",
        35: "Application windows (slow)", 36: "Show desktop", 37: "Show desktop (slow)",
        51: "Focus window drawer", 52: "Hide/show Dock",
        53: "Decrease brightness", 54: "Increase brightness", 57: "Focus status menus",
        59: "VoiceOver: on/off", 60: "Previous input source", 61: "Next input source",
        62: "Dashboard", 63: "Dashboard (slow)", 64: "Spotlight search", 65: "Finder search window",
        70: "Look up in dictionary", 73: "Front Row", 79: "Move left a space", 80: "Move left a space (slow)",
        81: "Move right a space", 82: "Move right a space (slow)", 98: "Help menu",
        118: "Desktop 1", 119: "Desktop 2", 120: "Desktop 3", 121: "Desktop 4",
        122: "Desktop 5", 123: "Desktop 6", 124: "Desktop 7", 125: "Desktop 8",
        126: "Desktop 9", 127: "Desktop 10", 128: "Desktop 11", 129: "Desktop 12",
        130: "Desktop 13", 131: "Desktop 14", 132: "Desktop 15", 133: "Desktop 16",
        160: "Launchpad", 162: "Accessibility controls", 163: "Notification Center",
        164: "Do Not Disturb", 184: "Screenshot and recording options", 190: "Quick Note",
        222: "Stage Manager",
    ]

    public static func name(for id: Int) -> String {
        names[id] ?? "System shortcut #\(id)"
    }
}
