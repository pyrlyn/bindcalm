import Foundation

/// Karabiner-Elements complex modifications in `~/.config/karabiner/karabiner.json`.
public struct KarabinerStrategy: HotKeyDiscoveryStrategy {
    public init() {}
    public var id: DiscoveryMethod { .karabiner }
    public var displayName: String { "Karabiner-Elements (karabiner.json)" }
    public var summary: String { "Сложные правила выбранного профиля Karabiner-Elements. Это HID-ремаппер: его сочетание срабатывает раньше всех. Простые замены одной клавиши не считаются сочетаниями." }

    public func discover(in context: DiscoveryContext) async throws -> [DiscoveredHotKey] {
        let url = context.home.appendingPathComponent(".config/karabiner/karabiner.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        guard let data = ConfigFiles.data(at: url), let json = ConfigFiles.jsonObject(from: data) else {
            throw DiscoveryError.unavailable("Не удалось прочитать ~/.config/karabiner/karabiner.json")
        }
        return claims(KarabinerParser.parse(json), method: id,
                      owner: ConfigFiles.owner(bundleID: "org.pqrs.Karabiner-Elements", fallbackName: "Karabiner-Elements", context: context),
                      file: ConfigFiles.displayPath(url, home: context.home))
    }
}

/// skhd bindings. Prefers `~/.config/skhd/skhdrc` and falls back to `~/.skhdrc`.
public struct SkhdStrategy: HotKeyDiscoveryStrategy {
    public init() {}
    public var id: DiscoveryMethod { .skhd }
    public var displayName: String { "skhd (~/.skhdrc)" }
    public var summary: String { "Сочетания из ~/.config/skhd/skhdrc или ~/.skhdrc. skhd перехватывает их через event tap. Файл читается, даже если демон не запущен." }

    public func discover(in context: DiscoveryContext) async throws -> [DiscoveredHotKey] {
        let xdg = context.home.appendingPathComponent(".config/skhd/skhdrc")
        let legacy = context.home.appendingPathComponent(".skhdrc")
        let url = FileManager.default.fileExists(atPath: xdg.path) ? xdg : legacy
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        guard let text = ConfigFiles.text(at: url) else {
            throw DiscoveryError.unavailable("Не удалось прочитать конфигурацию skhd")
        }
        return claims(SkhdParser.parse(text), method: id,
                      owner: HotKeyOwner(name: "skhd", bundleID: "com.koekeishiya.skhd"),
                      file: ConfigFiles.displayPath(url, home: context.home))
    }
}

/// `hs.hotkey.bind` / `hs.hotkey.new` in `~/.hammerspoon`, excluding the Spoons directory.
public struct HammerspoonStrategy: HotKeyDiscoveryStrategy {
    public init() {}
    public var id: DiscoveryMethod { .hammerspoon }
    public var displayName: String { "Hammerspoon (hs.hotkey)" }
    public var summary: String { "Литеральные вызовы hs.hotkey.bind и hs.hotkey.new в ~/.hammerspoon. Сочетания, собранные из переменных, не видны. Каталог Spoons пропускается." }

    public func discover(in context: DiscoveryContext) async throws -> [DiscoveredHotKey] {
        let root = context.home.appendingPathComponent(".hammerspoon")
        let files = ConfigFiles.files(in: root, extensions: ["lua"], skipDirectoryNames: ["Spoons"], maxDepth: 4, limit: 200)
        let owner = ConfigFiles.owner(bundleID: "org.hammerspoon.Hammerspoon", fallbackName: "Hammerspoon", context: context)
        var found: [DiscoveredHotKey] = []
        for file in files {
            try Task.checkCancellation()
            guard let text = ConfigFiles.text(at: file) else { continue }
            let parsed = HammerspoonParser.parse(text)
            found += claims(parsed, method: id, owner: owner, file: ConfigFiles.displayPath(file, home: context.home))
        }
        return found
    }
}

/// BetterTouchTool preset JSON (`.bttpreset`). The live SQLite database is left unread.
public struct BetterTouchToolStrategy: HotKeyDiscoveryStrategy {
    public init() {}
    public var id: DiscoveryMethod { .betterTouchTool }
    public var displayName: String { "BetterTouchTool (пресеты)" }
    public var summary: String { "Клавиатурные триггеры из .bttpreset в Application Support. Глобальная группа BT.G — глобальные сочетания, остальные — только в своём приложении. База SQLite не читается." }

    public func discover(in context: DiscoveryContext) async throws -> [DiscoveredHotKey] {
        let directory = context.home.appendingPathComponent("Library/Application Support/BetterTouchTool")
        var urls = ConfigFiles.files(in: directory, extensions: ["bttpreset", "json"], skipDirectoryNames: [], maxDepth: 2, limit: 50)
        let snapshot = directory.appendingPathComponent("bttdata2")
        if FileManager.default.fileExists(atPath: snapshot.path) { urls.append(snapshot) }
        let owner = ConfigFiles.owner(bundleID: "com.hegenberg.BetterTouchTool", fallbackName: "BetterTouchTool", context: context)
        var found: [DiscoveredHotKey] = []
        for url in urls {
            try Task.checkCancellation()
            guard let data = ConfigFiles.data(at: url) else { continue }
            let object = ConfigFiles.jsonObject(from: data) ?? ConfigFiles.propertyList(from: data)
            guard let object else { continue }
            found += claims(BetterTouchToolParser.parse(object), method: id, owner: owner,
                            file: ConfigFiles.displayPath(url, home: context.home))
        }
        return found
    }
}

/// Keyboard Maestro's macro library.
public struct KeyboardMaestroStrategy: HotKeyDiscoveryStrategy {
    public init() {}
    public var id: DiscoveryMethod { .keyboardMaestro }
    public var displayName: String { "Keyboard Maestro (макросы)" }
    public var summary: String { "Триггеры Hot Key из Keyboard Maestro Macros.plist. Выключенные группы помечаются выключенными; группа только для выбранных приложений считается сочетанием внутри приложения." }

    public func discover(in context: DiscoveryContext) async throws -> [DiscoveredHotKey] {
        let url = context.home.appendingPathComponent("Library/Application Support/Keyboard Maestro/Keyboard Maestro Macros.plist")
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        guard let data = ConfigFiles.data(at: url), let plist = ConfigFiles.propertyList(from: data) else {
            throw DiscoveryError.unavailable("Не удалось прочитать Keyboard Maestro Macros.plist")
        }
        return claims(KeyboardMaestroParser.parse(plist), method: id,
                      owner: ConfigFiles.owner(bundleID: "com.stairways.keyboardmaestro", fallbackName: "Keyboard Maestro", context: context),
                      file: ConfigFiles.displayPath(url, home: context.home))
    }
}

/// Alfred workflow hotkeys and the main Alfred hotkey preference.
public struct AlfredStrategy: HotKeyDiscoveryStrategy {
    public init() {}
    public var id: DiscoveryMethod { .alfred }
    public var displayName: String { "Alfred (воркфлоу и хоткей)" }
    public var summary: String { "Триггеры alfred.workflow.trigger.hotkey и главное сочетание Alfred из Alfred.alfredpreferences. Учитывается стандартная папка, не синхронизированная копия." }

    public func discover(in context: DiscoveryContext) async throws -> [DiscoveredHotKey] {
        let root = context.home.appendingPathComponent("Library/Application Support/Alfred/Alfred.alfredpreferences")
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }
        let owner = ConfigFiles.owner(bundleID: "com.runningwithcrayons.Alfred", fallbackName: "Alfred", context: context)
        var found: [DiscoveredHotKey] = []
        let workflows = root.appendingPathComponent("workflows")
        if let directories = try? FileManager.default.contentsOfDirectory(at: workflows, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for directory in directories {
                try Task.checkCancellation()
                let info = directory.appendingPathComponent("info.plist")
                guard let data = ConfigFiles.data(at: info),
                      let plist = ConfigFiles.propertyList(from: data) as? [String: Any] else { continue }
                found += claims(AlfredParser.parseWorkflow(plist), method: id, owner: owner,
                                file: ConfigFiles.displayPath(info, home: context.home))
            }
        }
        let preferences = ConfigFiles.files(in: root.appendingPathComponent("preferences"), extensions: ["plist"],
                                            skipDirectoryNames: [], maxDepth: 6, limit: 200)
        for file in preferences where file.path.lowercased().contains("hotkey") {
            try Task.checkCancellation()
            guard let data = ConfigFiles.data(at: file), let plist = ConfigFiles.propertyList(from: data) else { continue }
            let source = ConfigFiles.displayPath(file, home: context.home)
            found += claims(AlfredParser.parseHotkeyPreferences(plist, sourceName: source), method: id, owner: owner, file: "")
        }
        return found
    }
}

/// Raycast hotkeys stored as JSON or plist. The private database is not opened.
public struct RaycastStrategy: HotKeyDiscoveryStrategy {
    public init() {}
    public var id: DiscoveryMethod { .raycast }
    public var displayName: String { "Raycast (настройки)" }
    public var summary: String { "Ищет поля hotkey и shortcut в JSON и plist Raycast (~/.config/raycast, Application Support, com.raycast.macos.plist). Сочетания, которые лежат только во внутренней базе, не видны." }

    public func discover(in context: DiscoveryContext) async throws -> [DiscoveredHotKey] {
        let owner = ConfigFiles.owner(bundleID: "com.raycast.macos", fallbackName: "Raycast", context: context)
        var urls = ConfigFiles.files(in: context.home.appendingPathComponent(".config/raycast"),
                                     extensions: ["json", "plist"],
                                     skipDirectoryNames: ["extensions", "node_modules", "Cache", "Caches"],
                                     maxDepth: 5, limit: 100)
        urls += ConfigFiles.files(in: context.home.appendingPathComponent("Library/Application Support/com.raycast.macos"),
                                  extensions: ["json", "plist"],
                                  skipDirectoryNames: ["Cache", "Caches", "blob_storage", "GPUCache", "Code Cache", "extensions"],
                                  maxDepth: 4, limit: 100)
        let preferences = context.home.appendingPathComponent("Library/Preferences/com.raycast.macos.plist")
        if FileManager.default.fileExists(atPath: preferences.path) { urls.append(preferences) }
        var found: [DiscoveredHotKey] = []
        for url in urls {
            try Task.checkCancellation()
            guard let data = ConfigFiles.data(at: url) else { continue }
            let object = ConfigFiles.jsonObject(from: data) ?? ConfigFiles.propertyList(from: data)
            guard let object else { continue }
            found += claims(RaycastParser.parse(object), method: id, owner: owner,
                            file: ConfigFiles.displayPath(url, home: context.home))
        }
        return found
    }
}

private func claims(_ parsed: [ParsedConfigHotKey], method: DiscoveryMethod, owner: HotKeyOwner, file: String) -> [DiscoveredHotKey] {
    parsed.map { item in
        let source = file.isEmpty ? item.source : "\(file) → \(item.source)"
        return DiscoveredHotKey(combo: item.combo, owner: owner, method: method, confidence: .partial,
                                 scope: item.scope, action: item.action, enabled: item.enabled, source: source)
    }
}
