import Foundation

/// Single-key system bindings that are not symbolic hotkeys: the fn/Globe key action and
/// Caps Lock input-source switching (both in `com.apple.HIToolbox`).
public struct SystemKeysStrategy: HotKeyDiscoveryStrategy {
    public init() {}
    public var id: DiscoveryMethod { .systemKeys }
    public var displayName: String { "fn/🌐 and Caps Lock keys (HIToolbox)" }
    public var summary: String { "The action of the fn/🌐 key (switch input source, emoji, dictation) and the Caps Lock layout switch. Reliable." }

    public func discover(in context: DiscoveryContext) async throws -> [DiscoveredHotKey] {
        let domain = "com.apple.HIToolbox" as CFString
        var found: [DiscoveredHotKey] = []
        if let usage = (CFPreferencesCopyAppValue("AppleFnUsageType" as CFString, domain) as? NSNumber)?.intValue, usage != 0 {
            let action: String
            switch usage {
            case 1: action = "Switch input source"
            case 2: action = "Show emoji and symbols"
            case 3: action = "Start dictation"
            default: action = "Action #\(usage)"
            }
            found.append(DiscoveredHotKey(combo: KeyCombo(keyCode: 63, modifiers: []), owner: .macOS, method: id,
                                          confidence: .reliable, scope: .global, action: "fn/🌐: \(action)",
                                          source: "com.apple.HIToolbox → AppleFnUsageType = \(usage)"))
        }
        if let caps = (CFPreferencesCopyAppValue("TISRomanSwitchState" as CFString, domain) as? NSNumber)?.intValue, caps == 1 {
            found.append(DiscoveredHotKey(combo: KeyCombo(keyCode: 57, modifiers: []), owner: .macOS, method: id,
                                          confidence: .reliable, scope: .global, action: "Caps Lock: switch to ABC",
                                          source: "com.apple.HIToolbox → TISRomanSwitchState = 1"))
        }
        return found
    }
}
