import ShortcutClashCore
import SwiftUI

extension Confidence {
    var label: String {
        switch self {
        case .reliable: return "надёжно"
        case .partial: return "частично"
        case .heuristic: return "эвристика"
        }
    }

    var color: Color {
        switch self {
        case .reliable: return .green
        case .partial: return .orange
        case .heuristic: return .gray
        }
    }
}

extension HotKeyScope {
    var label: String {
        switch self {
        case .global: return "глобальное"
        case .inApp: return "в приложении"
        case .observed: return "наблюдение"
        }
    }
}

extension ConflictStatus {
    var label: String {
        switch self {
        case .conflict: return "Конфликт"
        case .layoutConflict: return "Конфликт из-за раскладки"
        case .inAppDuplicate: return "Дубль внутри приложения"
        case .none: return "Без конфликта"
        }
    }

    var color: Color {
        switch self {
        case .conflict: return .red
        case .layoutConflict: return .orange
        case .inAppDuplicate: return .secondary
        case .none: return .green
        }
    }
}

extension StrategyRunResult.State {
    var label: String {
        switch self {
        case .ok: return "работает"
        case .disabled: return "выключен"
        case .needsPermission: return "нужно разрешение"
        case .unavailable: return "недоступен"
        case .failed: return "ошибка"
        }
    }

    var symbol: String {
        switch self {
        case .ok: return "checkmark.circle.fill"
        case .disabled: return "pause.circle"
        case .needsPermission: return "lock.circle.fill"
        case .unavailable: return "minus.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .ok: return .green
        case .disabled: return .secondary
        case .needsPermission: return .orange
        case .unavailable: return .gray
        case .failed: return .red
        }
    }
}

struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.18)))
            .foregroundStyle(color)
    }
}
