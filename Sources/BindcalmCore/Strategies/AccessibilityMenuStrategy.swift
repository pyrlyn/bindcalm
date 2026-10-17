import AppKit
import ApplicationServices

/// Walks the menu bar of every running regular app through the Accessibility API and reads
/// `AXMenuItemCmdChar` / `AXMenuItemCmdVirtualKey` / `AXMenuItemCmdModifiers` / `AXMenuItemCmdGlyph`.
public struct AccessibilityMenuStrategy: HotKeyDiscoveryStrategy {
    public init() {}
    public var id: DiscoveryMethod { .accessibilityMenus }
    public var displayName: String { "Меню запущенных приложений (Accessibility)" }
    public var summary: String { "Читает строку меню каждого запущенного приложения через AX API. При смене активного приложения его меню перечитывается само. Требует «Универсальный доступ»." }
    public var requiredPermission: PermissionKind? { .accessibility }

    static let maxItemsPerApp = 6000
    static let maxDepth = 8
    /// The Services submenu mirrors the Services strategy; reading it per app would fake conflicts.
    static let skippedMenuTitles: Set<String> = ["Services", "Службы", "Dienste", "Services ", "Servicios", "Servizi"]
    /// macOS 15+ injects window-tiling items (Window → Move & Resize, Fill, Center) into every app with
    /// 🌐⌃ shortcuts. AX has no fn/Globe modifier bit, so they read as plain ⌃ combos and would falsely
    /// collide with Mission Control's ⌃arrows; they are skipped.
    static let tilingContainerTitles: Set<String> = ["Move & Resize", "Переместить и изменить размер", "Перемістити та змінити розмір"]
    static let tilingLeafTitles: Set<String> = ["Fill", "Center", "Centre", "Return to Previous Size", "Заполнить", "По центру",
                                                "Вернуть прежний размер", "Заповнити", "По центру"]

    static func isSystemTilingItem(path: [String], modifiers: ModifierSet) -> Bool {
        guard !modifiers.contains(.command), modifiers.contains(.control) else { return false }
        if path.contains(where: { tilingContainerTitles.contains($0) }) { return true }
        return path.last.map { tilingLeafTitles.contains($0) } ?? false
    }

    static let attributes = ["AXTitle", "AXMenuItemCmdChar", "AXMenuItemCmdVirtualKey",
                             "AXMenuItemCmdModifiers", "AXMenuItemCmdGlyph", "AXChildren"] as CFArray

    public func discover(in context: DiscoveryContext) async throws -> [DiscoveredHotKey] {
        guard AXIsProcessTrusted() else { throw DiscoveryError.permissionRequired(.accessibility) }
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.processIdentifier != getpid() && !$0.isTerminated
        }
        var found: [DiscoveredHotKey] = []
        var appleMenuRead = false
        for app in apps {
            try Task.checkCancellation()
            guard let read = readMenus(of: app, includeAppleMenu: !appleMenuRead, in: context) else { continue }
            if read.sawAppleMenu { appleMenuRead = true }
            found += read.claims
        }
        return found
    }

    /// In-app menu shortcuts for one app, skipping the Apple menu.
    /// Nil when the menu bar cannot be read. Does not prompt for Accessibility.
    public func menuClaims(of app: NSRunningApplication, in context: DiscoveryContext) -> [DiscoveredHotKey]? {
        readMenus(of: app, includeAppleMenu: false, in: context)?.claims
    }

    private struct MenuRead {
        var claims: [DiscoveredHotKey]
        var sawAppleMenu: Bool
    }

    /// Nil when this is not a readable regular app. `sawAppleMenu` is true once the first menu was walked,
    /// even if that menu contained no shortcuts, matching the full scan's "read the Apple menu once" rule.
    private func readMenus(of app: NSRunningApplication, includeAppleMenu: Bool, in context: DiscoveryContext) -> MenuRead? {
        guard AXIsProcessTrusted(), app.activationPolicy == .regular,
              app.processIdentifier != getpid(), !app.isTerminated else { return nil }
        let owner = context.owners.owner(for: app)
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 1.0)
        guard let menuBar = Self.value(element, "AXMenuBar").map({ $0 as! AXUIElement }) else { return nil }
        let topItems = (Self.value(menuBar, "AXChildren") as? [AXUIElement]) ?? []
        var found: [DiscoveredHotKey] = []
        var budget = Self.maxItemsPerApp
        var sawAppleMenu = false
        for (index, item) in topItems.enumerated() {
            let isAppleMenu = index == 0
            if isAppleMenu {
                sawAppleMenu = true
                if !includeAppleMenu { continue }
            }
            let itemOwner = isAppleMenu ? HotKeyOwner.macOS : owner
            let scope: HotKeyScope = isAppleMenu ? .global : .inApp
            walk(item, path: [], depth: 0, owner: itemOwner, scope: scope, appName: owner.name,
                 context: context, budget: &budget, into: &found)
        }
        return MenuRead(claims: found, sawAppleMenu: sawAppleMenu)
    }

    private func walk(_ element: AXUIElement, path: [String], depth: Int, owner: HotKeyOwner, scope: HotKeyScope,
                      appName: String, context: DiscoveryContext, budget: inout Int, into found: inout [DiscoveredHotKey]) {
        guard depth <= Self.maxDepth, budget > 0 else { return }
        budget -= 1
        var values: CFArray?
        guard AXUIElementCopyMultipleAttributeValues(element, Self.attributes, AXCopyMultipleAttributeOptions(rawValue: 0), &values) == .success,
              let list = values as? [AnyObject], list.count == 6 else { return }
        func clean(_ v: AnyObject) -> AnyObject? { CFGetTypeID(v) == AXValueGetTypeID() ? nil : v }
        let title = clean(list[0]) as? String ?? ""
        let cmdChar = clean(list[1]) as? String
        let virtualKey = (clean(list[2]) as? NSNumber)?.intValue
        let modifiers = (clean(list[3]) as? NSNumber)?.intValue ?? 0
        let glyph = (clean(list[4]) as? NSNumber)?.intValue ?? 0
        let children = clean(list[5]) as? [AXUIElement] ?? []

        if Self.skippedMenuTitles.contains(title), depth >= 1 { return }
        let currentPath = title.isEmpty ? path : path + [title]

        if let combo = Self.combo(cmdChar: cmdChar, virtualKey: virtualKey, glyph: glyph, modifiers: modifiers, layouts: context.layouts),
           !Self.isSystemTilingItem(path: currentPath, modifiers: combo.modifiers) {
            let label = scope == .global ? "\(appName): меню Apple" : appName
            found.append(DiscoveredHotKey(combo: combo, owner: owner, method: id, confidence: .reliable, scope: scope,
                                          action: currentPath.joined(separator: " → "),
                                          source: "AX \(label) → \(currentPath.joined(separator: " → "))",
                                          definingCharacter: (cmdChar?.isEmpty == false && glyph == 0) ? cmdChar : nil))
        }
        for child in children {
            walk(child, path: currentPath, depth: depth + 1, owner: owner, scope: scope, appName: appName,
                 context: context, budget: &budget, into: &found)
        }
    }

    static func combo(cmdChar: String?, virtualKey: Int?, glyph: Int, modifiers: Int, layouts: LayoutSnapshot) -> KeyCombo? {
        let mods = ModifierSet(axMenuModifiers: modifiers)
        if glyph > 0, let code = KeyEquivalentParser.keyCode(forMenuGlyph: glyph) {
            return KeyCombo(keyCode: code, modifiers: mods)
        }
        if let cmdChar, !cmdChar.isEmpty {
            return KeyEquivalentParser.combo(forCharacter: cmdChar, modifiers: mods, uppercaseImpliesShift: false, layouts: layouts)
        }
        if let virtualKey, virtualKey > 0, virtualKey < 128, cmdChar == nil {
            return KeyCombo(keyCode: UInt16(virtualKey), modifiers: mods)
        }
        return nil
    }

    static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value
    }
}

/// Replaces one app's in-app Accessibility claims and leaves every other finding alone.
public enum MenuClaimRefresh {
    public static func apply(ownerKey: String, fresh: [DiscoveredHotKey], to findings: [DiscoveredHotKey]) -> [DiscoveredHotKey] {
        let kept = findings.filter { finding in
            finding.method != .accessibilityMenus || finding.scope != .inApp || finding.owner.key != ownerKey
        }
        let incoming = fresh.filter { $0.method == .accessibilityMenus && $0.scope == .inApp && $0.owner.key == ownerKey }
        return kept + incoming
    }
}

extension AccessibilityMenuStrategy {
    /// Focused app according to Accessibility (can differ from NSWorkspace for panels and agents).
    public static func focusedApplicationPID() -> pid_t? {
        guard AXIsProcessTrusted() else { return nil }
        let systemWide = AXUIElementCreateSystemWide()
        guard let app = value(systemWide, "AXFocusedApplication") else { return nil }
        var pid: pid_t = 0
        return AXUIElementGetPid(app as! AXUIElement, &pid) == .success ? pid : nil
    }
}
