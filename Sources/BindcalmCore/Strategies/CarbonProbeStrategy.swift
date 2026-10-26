import Carbon
import Foundation

/// Tries to register candidate combos with `RegisterEventHotKey` and immediately unregisters them.
/// `eventHotKeyExistsErr` means another registration already holds the combo, but Carbon never says whose.
/// `GetEventHotKeyCount`/`GetEventHotKeyInfo` are looked up via dlsym only for diagnostics: they were
/// never public and their signatures are undocumented, so calling them would be guesswork.
public struct CarbonProbeStrategy: HotKeyDiscoveryStrategy {
    public init() {}
    public var id: DiscoveryMethod { .carbonProbe }
    public var displayName: String { "Carbon probe (RegisterEventHotKey)" }
    public var summary: String { "Tries to register each combo of a set and releases it immediately. An “already taken” error means another global shortcut; the owner is unknown. Heuristic." }

    public static let modifierSets: [ModifierSet] = [
        [.command], [.command, .shift], [.command, .option], [.command, .control], [.option], [.control],
        [.control, .option], [.option, .shift], [.control, .shift], [.command, .option, .shift],
        [.command, .control, .shift], [.command, .control, .option], [.control, .option, .shift], .hyper,
    ]

    public static var keyCodes: [UInt16] {
        let letters = "abcdefghijklmnopqrstuvwxyz0123456789`-=[];',./\\".compactMap { KeyCodes.usCharacters[$0] }
        return letters + [49, 36, 48, 53, 51, 123, 124, 125, 126] + KeyCodes.functionKeys.prefix(12)
    }

    public static var candidates: [KeyCombo] {
        modifierSets.flatMap { mods in keyCodes.map { KeyCombo(keyCode: $0, modifiers: mods) } }
    }

    public func discover(in context: DiscoveryContext) async throws -> [DiscoveredHotKey] {
        let hasPrivateCount = PrivateSymbols.lookup("GetEventHotKeyCount") != nil
        let taken = await MainActor.run { Self.probe(Self.candidates) }
        let note = hasPrivateCount ? " (GetEventHotKeyCount found but not called: the signature is undocumented)" : ""
        return taken.map { combo in
            DiscoveredHotKey(combo: combo, owner: .unknown, method: id, confidence: .heuristic, scope: .global,
                             action: "Taken by another registration",
                             source: "RegisterEventHotKey → eventHotKeyExistsErr\(note)")
        }
    }

    /// Must run on the main thread: hotkeys are bound to the application event target.
    @MainActor
    public static func probe(_ combos: [KeyCombo]) -> [KeyCombo] {
        var taken: [KeyCombo] = []
        let target = GetApplicationEventTarget()
        for (index, combo) in combos.enumerated() {
            var ref: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: OSType(0x5343_4C48), id: UInt32(index)) // 'SCLH'
            let status = RegisterEventHotKey(UInt32(combo.keyCode), combo.modifiers.carbonFlags, hotKeyID, target,
                                             OptionBits(kEventHotKeyExclusive), &ref)
            if status == noErr, let ref {
                UnregisterEventHotKey(ref)
            } else if status == OSStatus(eventHotKeyExistsErr) {
                taken.append(combo)
            }
        }
        return taken
    }
}
