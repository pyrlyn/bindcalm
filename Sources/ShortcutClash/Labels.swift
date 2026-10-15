import ShortcutClashCore
import SwiftUI

extension Confidence {
    var label: String {
        switch self {
        case .reliable: return "Reliable"
        case .partial: return "Partial"
        case .heuristic: return "Heuristic"
        }
    }

    var tone: Tone {
        switch self {
        case .reliable: return .ok
        case .partial: return .warn
        case .heuristic: return .muted
        }
    }
}

extension HotKeyScope {
    var label: String {
        switch self {
        case .global: return "Global"
        case .inApp: return "In app"
        case .observed: return "Observed"
        }
    }

    var tone: Tone { self == .global ? .accent : .muted }
}

extension ConflictStatus {
    var label: String {
        switch self {
        case .conflict: return "Conflict"
        case .layoutConflict: return "Layout conflict"
        case .inAppDuplicate: return "In-app duplicate"
        case .none: return "No conflict"
        }
    }

    var tone: Tone {
        switch self {
        case .conflict: return .danger
        case .layoutConflict: return .warn
        case .inAppDuplicate: return .muted
        case .none: return .ok
        }
    }
}

extension StrategyRunResult.State {
    var label: String {
        switch self {
        case .ok: return "Working"
        case .disabled: return "Off"
        case .needsPermission: return "Needs permission"
        case .unavailable: return "Unavailable"
        case .failed: return "Failed"
        }
    }

    var tone: Tone {
        switch self {
        case .ok: return .ok
        case .disabled: return .muted
        case .needsPermission: return .warn
        case .unavailable: return .muted
        case .failed: return .danger
        }
    }
}

extension PermissionKind {
    var title: String {
        switch self {
        case .accessibility: return "Accessibility"
        case .inputMonitoring: return "Input Monitoring"
        }
    }
}

enum MethodShortName {
    static func of(_ method: DiscoveryMethod) -> String {
        switch method {
        case .symbolicHotKeys: return "plist"
        case .skyLightSymbolic: return "SkyLight"
        case .carbonProbe: return "Carbon"
        case .userKeyEquivalents: return "NSUserKeyEq"
        case .preferencesScan: return "prefs"
        case .sandboxPreferences: return "sandbox"
        case .services: return "Services"
        case .karabiner: return "Karabiner"
        case .skhd: return "skhd"
        case .hammerspoon: return "HS"
        case .betterTouchTool: return "BTT"
        case .keyboardMaestro: return "KM"
        case .alfred: return "Alfred"
        case .raycast: return "Raycast"
        case .accessibilityMenus: return "AX"
        case .systemKeys: return "HIToolbox"
        case .nsEventMonitor: return "NSEvent"
        case .cgEventTap: return "tap"
        }
    }
}
