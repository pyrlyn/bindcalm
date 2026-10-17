import XCTest
@testable import BindcalmCore

final class KeyComboTests: XCTestCase {
    func testDisplayUsesAppleModifierOrder() {
        let combo = KeyCombo(keyCode: 40, modifiers: [.command, .shift, .control, .option])
        XCTAssertEqual(combo.display, "⌃⌥⇧⌘K")
    }

    func testFunctionFlagIsDroppedForArrowsAndFKeys() {
        XCTAssertEqual(KeyCombo(keyCode: 126, modifiers: [.control, .function]), KeyCombo(keyCode: 126, modifiers: [.control]))
        XCTAssertEqual(KeyCombo(keyCode: 122, modifiers: [.function]).modifiers, [])
        XCTAssertEqual(KeyCombo(keyCode: 12, modifiers: [.function]).modifiers, [.function])
    }

    func testModifierEncodingsRoundTrip() {
        let set: ModifierSet = [.command, .shift, .option, .control]
        XCTAssertEqual(ModifierSet(carbon: Int(set.carbonFlags)), set)
        XCTAssertEqual(ModifierSet(cocoa: set.cocoaFlags), set)
        XCTAssertEqual(ModifierSet(carbon: 0x100 | 0x200), [.command, .shift])
        XCTAssertEqual(ModifierSet(cocoa: 1_048_576 | 131_072), [.command, .shift])
    }

    func testAXMenuModifiersImplyCommandUnlessNoCommandBit() {
        XCTAssertEqual(ModifierSet(axMenuModifiers: 0), [.command])
        XCTAssertEqual(ModifierSet(axMenuModifiers: 1), [.command, .shift])
        XCTAssertEqual(ModifierSet(axMenuModifiers: 2 | 4), [.command, .option, .control])
        XCTAssertEqual(ModifierSet(axMenuModifiers: 8 | 4), [.control])
    }

    func testCodableRoundTrip() throws {
        let combo = KeyCombo(keyCode: 49, modifiers: [.command, .option])
        let data = try JSONEncoder().encode(combo)
        XCTAssertEqual(try JSONDecoder().decode(KeyCombo.self, from: data), combo)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("\"display\""))
    }
}
