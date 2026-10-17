import Foundation

/// Where a claim hooks the keyboard. Earlier layers see the key first and can consume it.
public enum HookLayer: Int, Codable, Sendable, Comparable, CaseIterable {
    case hidRemapper
    case eventTap
    case symbolicHotkey
    case carbonHotkey
    case frontmostMenu
    case unknown

    public static func < (lhs: HookLayer, rhs: HookLayer) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Russian name shown next to the winner.
    public var label: String {
        switch self {
        case .hidRemapper: return "HID-ремаппер"
        case .eventTap: return "event tap"
        case .symbolicHotkey: return "символическое сочетание"
        case .carbonHotkey: return "Carbon-сочетание"
        case .frontmostMenu: return "меню активного приложения"
        case .unknown: return "неизвестный уровень"
        }
    }

    /// Why a winner at this layer beats everything after it. Russian, shown in the detail panel.
    public var reason: String {
        switch self {
        case .hidRemapper:
            return "событие подменяется на уровне HID, до того как его увидит macOS."
        case .eventTap:
            return "перехватчик event tap забирает клавишу раньше символических сочетаний, Carbon и меню."
        case .symbolicHotkey:
            return "символическое сочетание обрабатывается системой раньше горячих клавиш приложений и меню."
        case .carbonHotkey:
            return "Carbon-сочетание (RegisterEventHotKey) срабатывает раньше меню активного приложения."
        case .frontmostMenu:
            return "это меню или служба активного приложения; на более раннем уровне клавишу никто не забрал."
        case .unknown:
            return "источник не сообщает уровень перехвата, а более ранних претендентов нет."
        }
    }
}

/// The claim most likely to run for one combo, or a tie when several owners hook at the same layer.
public struct ShortcutWinner: Hashable, Sendable {
    public var findings: [DiscoveredHotKey]
    public var layer: HookLayer
    public var isTie: Bool

    public var owners: [HotKeyOwner] {
        var seen = Set<String>()
        return findings.compactMap { seen.insert($0.owner.key).inserted ? $0.owner : nil }
    }

    public var explanation: String {
        let names = owners.map(\.name).joined(separator: ", ")
        if isTie {
            return "На уровне «\(layer.label)» сочетание перехватывают сразу несколько: \(names). Кто из них сработает, не определено."
        }
        return "Скорее всего сработает \(names): \(layer.reason)"
    }
}

public enum ShortcutRanking {
    /// Layer where this detection method's claims hook the keyboard.
    ///
    /// Hammerspoon entries come from `hs.hotkey`, which uses Carbon. skhd and BetterTouchTool install
    /// event taps. Services and App Shortcuts run with the frontmost app's menus. Preference heuristics
    /// do not say where the value is registered.
    public static func layer(of method: DiscoveryMethod) -> HookLayer {
        switch method {
        case .karabiner:
            return .hidRemapper
        case .skhd, .betterTouchTool, .cgEventTap:
            return .eventTap
        case .symbolicHotKeys, .skyLightSymbolic, .systemKeys:
            return .symbolicHotkey
        case .carbonProbe, .alfred, .raycast, .keyboardMaestro, .hammerspoon:
            return .carbonHotkey
        case .services, .userKeyEquivalents, .accessibilityMenus:
            return .frontmostMenu
        case .preferencesScan, .sandboxPreferences, .nsEventMonitor:
            return .unknown
        }
    }

    /// Likely winner among enabled, non-observed claims. Disabled and live-capture rows never win.
    /// Several owners on the earliest layer are a tie. Returns nil when nothing is eligible.
    public static func winner(in findings: [DiscoveredHotKey]) -> ShortcutWinner? {
        let active = findings.filter { $0.enabled && $0.scope != .observed }
        guard let best = active.map({ layer(of: $0.method) }).min() else { return nil }
        let atBest = active.filter { layer(of: $0.method) == best }
        let ownerCount = Set(atBest.map(\.owner.key)).count
        return ShortcutWinner(findings: atBest, layer: best, isTie: ownerCount > 1)
    }
}
