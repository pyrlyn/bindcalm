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
        7: "Фокус на строку меню", 8: "Фокус на Dock", 9: "Фокус на активное/следующее окно",
        10: "Фокус на панель инструментов окна", 11: "Фокус на плавающее окно",
        12: "Включить/выключить клавиатурный доступ", 13: "Изменить поведение Tab",
        15: "Увеличение: вкл/выкл", 17: "Увеличение: приблизить", 19: "Увеличение: отдалить",
        21: "Инверсия цветов", 23: "Сглаживание изображения при увеличении",
        25: "Увеличить контраст", 26: "Уменьшить контраст",
        27: "Фокус на следующее окно", 28: "Снимок экрана в файл",
        29: "Снимок экрана в буфер", 30: "Снимок области в файл", 31: "Снимок области в буфер",
        32: "Mission Control", 33: "Окна приложения", 34: "Mission Control (медленно)",
        35: "Окна приложения (медленно)", 36: "Показать рабочий стол", 37: "Показать рабочий стол (медленно)",
        51: "Фокус на ящик окна", 52: "Скрыть/показать Dock",
        53: "Уменьшить яркость", 54: "Увеличить яркость", 57: "Фокус на меню статуса",
        59: "VoiceOver: вкл/выкл", 60: "Предыдущий источник ввода", 61: "Следующий источник ввода",
        62: "Dashboard", 63: "Dashboard (медленно)", 64: "Поиск Spotlight", 65: "Окно поиска Finder",
        70: "Поиск в словаре", 73: "Front Row", 79: "Пространство слева", 80: "Пространство слева (медленно)",
        81: "Пространство справа", 82: "Пространство справа (медленно)", 98: "Меню «Справка»",
        118: "Рабочий стол 1", 119: "Рабочий стол 2", 120: "Рабочий стол 3", 121: "Рабочий стол 4",
        122: "Рабочий стол 5", 123: "Рабочий стол 6", 124: "Рабочий стол 7", 125: "Рабочий стол 8",
        126: "Рабочий стол 9", 127: "Рабочий стол 10", 128: "Рабочий стол 11", 129: "Рабочий стол 12",
        130: "Рабочий стол 13", 131: "Рабочий стол 14", 132: "Рабочий стол 15", 133: "Рабочий стол 16",
        160: "Launchpad", 162: "Панель универсального доступа", 163: "Центр уведомлений",
        164: "Не беспокоить", 184: "Параметры снимка экрана и записи", 190: "Быстрая заметка",
        222: "Stage Manager",
    ]

    public static func name(for id: Int) -> String {
        names[id] ?? "Системное сочетание #\(id)"
    }
}
