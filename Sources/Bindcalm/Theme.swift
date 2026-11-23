import AppKit
import SwiftUI

/// User-selectable appearance. `system` follows macOS; the others force one theme.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "appearanceMode"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Design v3 tokens (design/tokens.json) as dynamic colors: each resolves to the light or dark value
/// from the effective appearance, so the manual override (`preferredColorScheme`) and the system
/// setting both work without any per-view branching.
enum Theme {
    // MARK: Surfaces
    static let bg = dyn(0xE8EDF4, 0x0F1319)
    static let surface = dyn(0xFFFFFF, 0x161B23)
    static let card = dyn(0xFFFFFF, 0x1A202A)
    static let sidebar = dyn(0xF6F8FC, 0x161B23, 0.90, 0.88)
    static let toolbar = dyn(0xFAFBFD, 0x161B23, 0.92, 0.90)
    static let tint = dyn(0x7FA6FF, 0x7DA8FF, 0.55, 0.45)
    // Reduce Transparency fallbacks
    static let opaque = dyn(0xF6F8FB, 0x161B24)
    static let opaqueRaised = dyn(0xFFFFFF, 0x1E2430)
    static let opaqueBorder = dyn(0xC9D2DF, 0x323A49)

    // MARK: Text and tones
    static let fg = dyn(0x0E1522, 0xF2F4F8)
    static let muted = dyn(0x4B5870, 0xA3ACBB)
    static let accent = dyn(0x1F4FD1, 0x7DA8FF)
    static let onAccent = dyn(0xFFFFFF, 0x06122B)
    static let danger = dyn(0xB3261E, 0xFF7A75)
    static let dangerFill = dyn(0xC7352B, 0xFF7A75)
    static let onDanger = dyn(0xFFFFFF, 0x2A0806)
    static let ok = dyn(0x0A6670, 0x5CD9E0)
    static let warn = dyn(0x7D5200, 0xF2B84B)

    // MARK: Controls
    static let control = dyn(0xFAFBFD, 0x212733)
    static let controlHover = dyn(0xFFFFFF, 0x2A313D)
    static let controlActive = dyn(0xEBEFF6, 0x1C212A)
    static let input = dyn(0xFBFCFE, 0x12161D)
    static let border = dyn(0x0E1522, 0xFFFFFF, 0.14, 0.10)
    static let borderStrong = dyn(0x0E1522, 0xFFFFFF, 0.26, 0.18)
    static let highlight = dyn(0xFFFFFF, 0xFFFFFF, 1.0, 0.14)
    static let hairline = dyn(0x0E1522, 0xFFFFFF, 0.08, 0.07)
    static let selected = dyn(0x1F4FD1, 0x7DA8FF, 0.09, 0.14)
    static let shadow = dyn(0x1E2D50, 0x000000, 0.16, 0.35)
    static let shadowSoft = dyn(0x1E2D50, 0x000000, 0.10, 0.28)
    static let inset = dyn(0x1E2D50, 0x000000, 0.14, 0.30)
    static let primaryTop = dyn(0x2457DC, 0x86B0FF)
    static let primaryBottom = dyn(0x1F4FD1, 0x7DA8FF)
    static let primaryHighlight = dyn(0xFFFFFF, 0xFFFFFF, 0.30, 0.45)
    static let trackOff = dyn(0x0E1522, 0xFFFFFF, 0.22, 0.16)
    static let knob = dyn(0xFFFFFF, 0xF2F4F8)

    // MARK: Metrics (4/8 grid, with the v1 insets kept on purpose)
    enum Radius {
        static let control: CGFloat = 8
        static let row: CGFloat = 10
        static let card: CGFloat = 12
    }

    enum Size {
        static let sidebarWidth: CGFloat = 400
        static let toolbarHeight: CGFloat = 52
        static let button: CGFloat = 32
        static let buttonSmall: CGFloat = 26
        static let field: CGFloat = 36
        static let row: CGFloat = 68
        static let rowPitch: CGFloat = 72
        static let badge: CGFloat = 19
        static let bead: CGFloat = 24
        static let orb: CGFloat = 72
    }

    enum Motion {
        static let hover: Double = 0.12
        static let press: Double = 0.06
        static let release: Double = 0.16
        static let focus: Double = 0.12
        static let toggle: Double = 0.16
    }

    // MARK: Helpers
    private static func dyn(_ light: UInt32, _ dark: UInt32, _ lightAlpha: CGFloat = 1, _ darkAlpha: CGFloat = 1) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return rgb(isDark ? dark : light, alpha: isDark ? darkAlpha : lightAlpha)
        })
    }

    private static func rgb(_ value: UInt32, alpha: CGFloat) -> NSColor {
        NSColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: alpha)
    }
}

/// Semantic tone of a badge, status text or empty state.
enum Tone {
    case accent, ok, warn, danger, muted

    var color: Color {
        switch self {
        case .accent: return Theme.accent
        case .ok: return Theme.ok
        case .warn: return Theme.warn
        case .danger: return Theme.danger
        case .muted: return Theme.muted
        }
    }
}
