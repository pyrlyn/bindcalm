import Foundation

/// Asks the WindowServer for the *effective* value of every symbolic hotkey via the private
/// SkyLight calls `CGSGetSymbolicHotKeyValue` / `CGSIsSymbolicHotKeyEnabled`, resolved with dlsym.
/// Read-only: the matching setters are never called.
public struct SkyLightSymbolicStrategy: HotKeyDiscoveryStrategy {
    public init() {}
    public var id: DiscoveryMethod { .skyLightSymbolic }
    public var displayName: String { "Системные сочетания (SkyLight, приватный API)" }
    public var summary: String { "Фактические значения системных сочетаний из WindowServer, включая значения по умолчанию, которых нет в plist. Приватный API — может исчезнуть." }

    typealias GetValueFn = @convention(c) (Int32, UnsafeMutablePointer<UInt16>?, UnsafeMutablePointer<UInt16>?, UnsafeMutablePointer<UInt64>?) -> Int32
    typealias IsEnabledFn = @convention(c) (Int32) -> Bool

    public static let maxID: Int32 = 300

    public func discover(in context: DiscoveryContext) async throws -> [DiscoveredHotKey] {
        guard let getPtr = PrivateSymbols.lookup("CGSGetSymbolicHotKeyValue") ?? PrivateSymbols.lookup("SLSGetSymbolicHotKeyValue") else {
            throw DiscoveryError.unavailable("CGSGetSymbolicHotKeyValue не найден в этой версии macOS")
        }
        let getValue = unsafeBitCast(getPtr, to: GetValueFn.self)
        let isEnabled = (PrivateSymbols.lookup("CGSIsSymbolicHotKeyEnabled") ?? PrivateSymbols.lookup("SLSIsSymbolicHotKeyEnabled"))
            .map { unsafeBitCast($0, to: IsEnabledFn.self) }

        var found: [DiscoveredHotKey] = []
        for hotKey in Int32(0)...Self.maxID {
            var character: UInt16 = 0
            var keyCode: UInt16 = 0
            // CGSModifierFlags is an enum (4 bytes); an 8-byte zeroed buffer is safe either way.
            var modifiers: UInt64 = 0
            guard getValue(hotKey, &character, &keyCode, &modifiers) == 0,
                  keyCode != 0xFFFF, !(keyCode == 0 && modifiers == 0 && character == 0) else { continue }
            let mods = ModifierSet(cocoa: modifiers & 0xFFFF_FFFF)
            let combo = KeyCombo(keyCode: keyCode, modifiers: mods)
            // Unmodified arrows/Help entries exist in the table but are not keyboard hotkeys in practice.
            guard combo.modifiers.isShortcutLike || KeyCodes.isFunctionKey(keyCode) else { continue }
            // The WindowServer table also holds internal entries (app switcher, minimize, window tiling with
            // the Globe modifier, ...) that are not user-facing global hotkeys. Without a public list their
            // meaning is unknown, so they are shown but never counted as active claims.
            let documented = SymbolicHotKeysParser.names[Int(hotKey)] != nil
            let active = isEnabled?(hotKey) ?? true
            found.append(DiscoveredHotKey(combo: combo, owner: .macOS, method: id, confidence: documented ? .partial : .heuristic,
                                          scope: .global,
                                          action: documented ? SymbolicHotKeysParser.name(for: Int(hotKey))
                                              : "\(SymbolicHotKeysParser.name(for: Int(hotKey))) (назначение не задокументировано)",
                                          enabled: documented && active,
                                          source: "CGSGetSymbolicHotKeyValue(\(hotKey)) → \(active ? "enabled" : "disabled")"))
        }
        return found
    }
}
