import XCTest
@testable import ShortcutClashCore

final class FormatDetectorTests: XCTestCase {
    func testMASShortcutDictionary() {
        let plist: [String: Any] = ["GlobalShortcut": ["keyCode": 40, "modifierFlags": 1_179_648]]
        let hits = ShortcutFormatDetector.detect(in: plist)
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits[0].format, .masShortcut)
        XCTAssertEqual(hits[0].combo, KeyCombo(keyCode: 40, modifiers: [.command, .shift]))
        XCTAssertEqual(hits[0].keyPath, "GlobalShortcut")
    }

    func testShortcutRecorderDictionary() {
        let plist: [String: Any] = ["prefs": ["toggle": ["keyCode": 49, "modifierFlags": 524_288, "characters": " "]]]
        let hits = ShortcutFormatDetector.detect(in: plist)
        XCTAssertEqual(hits.first?.format, .shortcutRecorder)
        XCTAssertEqual(hits.first?.combo, KeyCombo(keyCode: 49, modifiers: [.option]))
        XCTAssertEqual(hits.first?.keyPath, "prefs.toggle")
    }

    func testKeyboardShortcutsJSONString() {
        let plist: [String: Any] = ["KeyboardShortcuts_toggleApp": "{\"carbonModifiers\":2560,\"carbonKeyCode\":17}"]
        let hits = ShortcutFormatDetector.detect(in: plist)
        XCTAssertEqual(hits.first?.format, .keyboardShortcuts)
        XCTAssertEqual(hits.first?.combo, KeyCombo(keyCode: 17, modifiers: [.option, .shift]))
    }

    func testArchivedDataIsInspected() throws {
        let inner: [String: Any] = ["$objects": ["$null", ["KeyCode": 3, "ModifierFlags": 1_310_720]]]
        let data = try PropertyListSerialization.data(fromPropertyList: inner, format: .binary, options: 0)
        let hits = ShortcutFormatDetector.detect(in: ["archived": data])
        XCTAssertEqual(hits.first?.combo, KeyCombo(keyCode: 3, modifiers: [.command, .control]))
    }

    func testSymbolicStyleParametersAndStrings() {
        let plist: [String: Any] = [
            "CustomizedKeyboardShortcut": ["enabled": true, "value": ["parameters": [65535, 49, 1_572_864]]],
            "raycastGlobalHotkey": "Option-Command-49",
            "someTitle": "cmd+shift+k",
        ]
        let hits = ShortcutFormatDetector.detect(in: plist)
        XCTAssertEqual(Set(hits.map(\.format)), [.symbolicParameters, .hotKeyString])
        XCTAssertEqual(hits.count, 2, "strings under keys that do not look like hotkeys must be ignored")
    }

    func testUnmodifiedLettersAreIgnored() {
        let plist: [String: Any] = ["x": ["keyCode": 0, "modifierFlags": 0], "y": ["keyCode": 96, "modifierFlags": 0]]
        let hits = ShortcutFormatDetector.detect(in: plist)
        XCTAssertEqual(hits.map(\.combo), [KeyCombo(keyCode: 96, modifiers: [])])
    }
}
