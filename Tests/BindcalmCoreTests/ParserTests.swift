import XCTest
@testable import BindcalmCore

final class ParserTests: XCTestCase {
    func testUserKeyEquivalentNotation() {
        XCTAssertEqual(KeyEquivalentParser.parseUserKeyEquivalent("@$k"), KeyCombo(keyCode: 40, modifiers: [.command, .shift]))
        XCTAssertEqual(KeyEquivalentParser.parseUserKeyEquivalent("@K"), KeyCombo(keyCode: 40, modifiers: [.command, .shift]))
        XCTAssertEqual(KeyEquivalentParser.parseUserKeyEquivalent("^~\u{F702}"), KeyCombo(keyCode: 123, modifiers: [.control, .option]))
        XCTAssertEqual(KeyEquivalentParser.parseUserKeyEquivalent("@?"), KeyCombo(keyCode: 44, modifiers: [.command, .shift]))
        XCTAssertEqual(KeyEquivalentParser.parseUserKeyEquivalent("@#1"), KeyCombo(keyCode: 83, modifiers: [.command]))
        XCTAssertEqual(KeyEquivalentParser.parseUserKeyEquivalent("@\u{F704}"), KeyCombo(keyCode: 122, modifiers: [.command]))
        XCTAssertNil(KeyEquivalentParser.parseUserKeyEquivalent(""))
        XCTAssertNil(KeyEquivalentParser.parseUserKeyEquivalent("@ab"))
    }

    func testAXCharacterDoesNotImplyShift() {
        let combo = KeyEquivalentParser.combo(forCharacter: "K", modifiers: [.command], uppercaseImpliesShift: false)
        XCTAssertEqual(combo, KeyCombo(keyCode: 40, modifiers: [.command]))
    }

    func testNonLatinCharacterResolvesThroughLayouts() {
        let russian = LayoutSnapshot.Layout(id: "ru", name: "Русская", isCurrent: true, isASCIICapable: false,
                                            unshifted: [8: "с", 40: "л"], shifted: [8: "С"])
        let snapshot = LayoutSnapshot(layouts: [russian])
        XCTAssertEqual(KeyEquivalentParser.combo(forCharacter: "с", modifiers: [.command], uppercaseImpliesShift: false, layouts: snapshot),
                       KeyCombo(keyCode: 8, modifiers: [.command]))
        XCTAssertNil(KeyEquivalentParser.combo(forCharacter: "ж", modifiers: [.command], uppercaseImpliesShift: false, layouts: snapshot))
    }

    func testMenuGlyphs() {
        XCTAssertEqual(KeyEquivalentParser.keyCode(forMenuGlyph: 0x64), 123)
        XCTAssertEqual(KeyEquivalentParser.keyCode(forMenuGlyph: 0x6F), 122)
        XCTAssertEqual(KeyEquivalentParser.keyCode(forMenuGlyph: 0x7A), 111)
        XCTAssertEqual(KeyEquivalentParser.keyCode(forMenuGlyph: 0x1B), 53)
        XCTAssertNil(KeyEquivalentParser.keyCode(forMenuGlyph: 0x12))
    }

    func testHotKeyStrings() {
        XCTAssertEqual(KeyEquivalentParser.parseHotKeyString("Command-49"), KeyCombo(keyCode: 49, modifiers: [.command]))
        XCTAssertEqual(KeyEquivalentParser.parseHotKeyString("Option-Command-49"), KeyCombo(keyCode: 49, modifiers: [.command, .option]))
        XCTAssertEqual(KeyEquivalentParser.parseHotKeyString("cmd+shift+k"), KeyCombo(keyCode: 40, modifiers: [.command, .shift]))
        XCTAssertEqual(KeyEquivalentParser.parseHotKeyString("ctrl-alt-space"), KeyCombo(keyCode: 49, modifiers: [.control, .option]))
        XCTAssertEqual(KeyEquivalentParser.parseHotKeyString("⌘⇧K"), KeyCombo(keyCode: 40, modifiers: [.command, .shift]))
        XCTAssertEqual(KeyEquivalentParser.parseHotKeyString("hyper+t"), KeyCombo(keyCode: 17, modifiers: .hyper))
        XCTAssertEqual(KeyEquivalentParser.parseHotKeyString("cmd+1"), KeyCombo(keyCode: 18, modifiers: [.command]))
        XCTAssertNil(KeyEquivalentParser.parseHotKeyString("shift+k"))
        XCTAssertNil(KeyEquivalentParser.parseHotKeyString("hello world"))
        XCTAssertNil(KeyEquivalentParser.parseHotKeyString("k"))
    }

    func testSymbolicHotKeysPlist() {
        let root: [String: Any] = [
            "64": ["enabled": true, "value": ["parameters": [32, 49, 1_048_576], "type": "standard"]],
            "60": ["enabled": false, "value": ["parameters": [32, 49, 262_144], "type": "standard"]],
            "33": ["enabled": true, "value": ["parameters": [65535, 125, 8_650_752], "type": "standard"]],
            "52": ["enabled": true, "value": ["parameters": [65535, 65535, 0], "type": "standard"]],
            "999": ["enabled": true, "value": ["parameters": [65535, 1, 0], "type": "button"]],
        ]
        let entries = SymbolicHotKeysParser.parse(root)
        XCTAssertEqual(entries.map(\.id), [33, 52, 60, 64, 999])
        XCTAssertEqual(entries.first { $0.id == 64 }?.combo, KeyCombo(keyCode: 49, modifiers: [.command]))
        XCTAssertEqual(entries.first { $0.id == 60 }?.enabled, false)
        // ⌃↓ with the implicit fn and numeric-pad flags stripped.
        XCTAssertEqual(entries.first { $0.id == 33 }?.combo, KeyCombo(keyCode: 125, modifiers: [.control]))
        XCTAssertNil(entries.first { $0.id == 52 }?.combo)
        XCTAssertNil(entries.first { $0.id == 999 }?.combo)
        XCTAssertEqual(SymbolicHotKeysParser.name(for: 64), "Spotlight search")
    }

    func testServicesParsing() {
        let services: [[String: Any]] = [
            ["NSMenuItem": ["default": "Open man Page in Terminal"], "NSKeyEquivalent": ["default": "M"]],
            ["NSMenuItem": ["default": "Make Sticky"], "NSKeyEquivalent": ["default": "y"]],
            ["NSMenuItem": ["default": "No shortcut"]],
        ]
        let parsed = ServicesParser.parseInfoPlistServices(services)
        XCTAssertEqual(parsed.count, 2)
        XCTAssertEqual(parsed[0].combo, KeyCombo(keyCode: 46, modifiers: [.command, .shift]))
        XCTAssertEqual(parsed[1].combo, KeyCombo(keyCode: 16, modifiers: [.command]))

        let status: [String: Any] = [
            "com.apple.Terminal - Open man Page in Terminal - openManPage": ["key_equivalent": "@~m", "enabled_services_menu": true],
            "(null) - My Shortcut - runWorkflowAsService": ["key_equivalent": "^@j"],
            "com.apple.Notes - Add to Notes - addToNotes": ["enabled_services_menu": false],
        ]
        let entries = ServicesParser.parseStatus(status)
        let terminal = entries.first { $0.providerBundleID == "com.apple.Terminal" }
        XCTAssertEqual(terminal?.combo, KeyCombo(keyCode: 46, modifiers: [.command, .option]))
        XCTAssertEqual(terminal?.title, "Open man Page in Terminal")
        let workflow = entries.first { $0.title == "My Shortcut" }
        XCTAssertNil(workflow?.providerBundleID)
        XCTAssertEqual(workflow?.combo, KeyCombo(keyCode: 38, modifiers: [.command, .control]))
        // A shortcut without an enabled flag is not confirmation that the service is on.
        XCTAssertEqual(workflow?.enabled, false)
        XCTAssertEqual(terminal?.enabled, true)
        XCTAssertEqual(entries.first { $0.providerBundleID == "com.apple.Notes" }?.enabled, false)

        let contextOnly: [String: Any] = [
            "com.apple.Safari - Search With Google - searchWithGoogle": ["enabled_context_menu": true, "enabled_services_menu": false],
            "com.apple.Finder - New Terminal at Folder - newTerminalAtFolder": ["enabled_context_menu": 1],
        ]
        let flags = ServicesParser.parseStatus(contextOnly)
        XCTAssertEqual(flags.first { $0.providerBundleID == "com.apple.Safari" }?.enabled, false)
        XCTAssertEqual(flags.first { $0.providerBundleID == "com.apple.Finder" }?.enabled, true)
    }

    func testUnconfirmedServiceDefaultsAreDisabled() {
        let services = ServicesParser.parseInfoPlistServices([
            ["NSMenuItem": ["default": "Open man Page in Terminal"], "NSKeyEquivalent": ["default": "M"]],
            ["NSMenuItem": ["default": "Make Sticky"], "NSKeyEquivalent": ["default": "y"]],
        ])
        let open = services[0]
        let sticky = services[1]
        let confirmedOff = ServiceStatusEntry(providerBundleID: "com.apple.Terminal", title: open.title, combo: nil,
                                               enabled: false, rawKey: "com.apple.Terminal - Open man Page in Terminal - openManPage")
        let overridden = ServiceStatusEntry(providerBundleID: "com.apple.Terminal", title: sticky.title,
                                            combo: KeyCombo(keyCode: 0, modifiers: [.command]), enabled: true, rawKey: "status")

        let unconfirmed = ServicesParser.resolveDefault(open, status: nil)
        XCTAssertEqual(unconfirmed?.enabled, false)
        XCTAssertEqual(unconfirmed?.confirmed, false)
        XCTAssertEqual(unconfirmed?.combo, open.combo)

        let confirmed = ServicesParser.resolveDefault(open, status: confirmedOff)
        XCTAssertEqual(confirmed?.enabled, false)
        XCTAssertEqual(confirmed?.confirmed, true)
        XCTAssertEqual(confirmed?.combo, open.combo)

        XCTAssertNil(ServicesParser.resolveDefault(sticky, status: overridden))
    }
}

final class AccessibilityFilterTests: XCTestCase {
    func testSystemTilingItemsAreRecognised() {
        XCTAssertTrue(AccessibilityMenuStrategy.isSystemTilingItem(path: ["Window", "Move & Resize", "Left"], modifiers: [.control]))
        XCTAssertTrue(AccessibilityMenuStrategy.isSystemTilingItem(path: ["Window", "Fill"], modifiers: [.control]))
        XCTAssertFalse(AccessibilityMenuStrategy.isSystemTilingItem(path: ["Window", "Fill"], modifiers: [.command, .control]))
        XCTAssertFalse(AccessibilityMenuStrategy.isSystemTilingItem(path: ["Debugger", "Pause"], modifiers: [.control]))
    }

    func testAXComboResolution() {
        XCTAssertEqual(AccessibilityMenuStrategy.combo(cmdChar: "K", virtualKey: nil, glyph: 0, modifiers: 1, layouts: .empty),
                       KeyCombo(keyCode: 40, modifiers: [.command, .shift]))
        XCTAssertEqual(AccessibilityMenuStrategy.combo(cmdChar: "", virtualKey: nil, glyph: 0x64, modifiers: 4 | 8, layouts: .empty),
                       KeyCombo(keyCode: 123, modifiers: [.control]))
        XCTAssertNil(AccessibilityMenuStrategy.combo(cmdChar: nil, virtualKey: nil, glyph: 0, modifiers: 0, layouts: .empty))
    }
}

final class PreferencesScopeTests: XCTestCase {
    func testBareCommandShortcutsAreTreatedAsInApp() {
        XCTAssertEqual(PreferencesScanStrategy.likelyScope(of: KeyCombo(keyCode: 1, modifiers: [.command])), .inApp)
        XCTAssertEqual(PreferencesScanStrategy.likelyScope(of: KeyCombo(keyCode: 49, modifiers: [.command])), .global)
        XCTAssertEqual(PreferencesScanStrategy.likelyScope(of: KeyCombo(keyCode: 19, modifiers: [.command, .shift])), .global)
        XCTAssertEqual(PreferencesScanStrategy.likelyScope(of: KeyCombo(keyCode: 40, modifiers: [.control, .option])), .global)
    }
}
