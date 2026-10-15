import XCTest
@testable import ShortcutClashCore

final class ConflictAnalyzerTests: XCTestCase {
    let cmdSpace = KeyCombo(keyCode: 49, modifiers: [.command])
    let raycast = HotKeyOwner(name: "Raycast", bundleID: "com.raycast.macos")
    let xcode = HotKeyOwner(name: "Xcode", bundleID: "com.apple.dt.Xcode")
    let safari = HotKeyOwner(name: "Safari", bundleID: "com.apple.Safari")

    func finding(_ owner: HotKeyOwner, _ scope: HotKeyScope, _ method: DiscoveryMethod = .preferencesScan,
                 action: String = "a", enabled: Bool = true, combo: KeyCombo? = nil, char: String? = nil) -> DiscoveredHotKey {
        DiscoveredHotKey(combo: combo ?? cmdSpace, owner: owner, method: method, confidence: .reliable, scope: scope,
                         action: action, enabled: enabled, source: "test-\(method.rawValue)-\(action)", definingCharacter: char)
    }

    func testGlobalVersusGlobalOfDifferentOwnersIsConflict() {
        XCTAssertEqual(ConflictAnalyzer.status(of: [finding(.macOS, .global, .symbolicHotKeys), finding(raycast, .global)]), .conflict)
    }

    func testSameOwnerFoundByTwoMethodsIsNotConflict() {
        XCTAssertEqual(ConflictAnalyzer.status(of: [finding(.macOS, .global, .symbolicHotKeys), finding(.macOS, .global, .skyLightSymbolic)]), .none)
    }

    func testInAppAcrossDifferentAppsIsNotConflict() {
        XCTAssertEqual(ConflictAnalyzer.status(of: [finding(xcode, .inApp, .accessibilityMenus), finding(safari, .inApp, .accessibilityMenus)]), .none)
    }

    func testGlobalVersusInAppIsConflict() {
        XCTAssertEqual(ConflictAnalyzer.status(of: [finding(raycast, .global), finding(xcode, .inApp, .accessibilityMenus)]), .conflict)
    }

    func testGlobalOwnerAlsoInItsOwnMenuIsNotConflict() {
        XCTAssertEqual(ConflictAnalyzer.status(of: [finding(raycast, .global), finding(raycast, .inApp, .accessibilityMenus)]), .none)
    }

    func testUnknownProbeOwnerCorroboratesKnownGlobal() {
        XCTAssertEqual(ConflictAnalyzer.status(of: [finding(.macOS, .global, .symbolicHotKeys), finding(.unknown, .global, .carbonProbe)]), .none)
        XCTAssertEqual(ConflictAnalyzer.status(of: [finding(.unknown, .global, .carbonProbe), finding(safari, .inApp, .accessibilityMenus)]), .conflict)
    }

    func testDisabledAndObservedClaimsAreIgnored() {
        XCTAssertEqual(ConflictAnalyzer.status(of: [finding(.macOS, .global, .symbolicHotKeys, enabled: false), finding(raycast, .global)]), .none)
        XCTAssertEqual(ConflictAnalyzer.status(of: [finding(raycast, .global), finding(safari, .observed, .cgEventTap)]), .none)
    }

    func testInAppDuplicate() {
        XCTAssertEqual(ConflictAnalyzer.status(of: [finding(xcode, .inApp, .accessibilityMenus, action: "Build"),
                                                    finding(xcode, .inApp, .accessibilityMenus, action: "Run")]), .inAppDuplicate)
    }

    func testGroupsSortConflictsFirstAndCollectMethods() {
        let other = KeyCombo(keyCode: 40, modifiers: [.command])
        let groups = ConflictAnalyzer.groups(from: [
            finding(xcode, .inApp, .accessibilityMenus, combo: other),
            finding(.macOS, .global, .symbolicHotKeys),
            finding(raycast, .global),
        ])
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].combo, cmdSpace)
        XCTAssertEqual(groups[0].status, .conflict)
        XCTAssertEqual(Set(groups[0].methods), [.symbolicHotKeys, .preferencesScan])
        XCTAssertEqual(groups[0].owners.count, 2)
    }

    func testLayoutConflictWhenCharacterMovesToAGloballyOwnedKey() {
        // German QWERTZ swaps Y (16) and Z (6).
        let us = LayoutSnapshot.Layout(id: "us", name: "U.S.", isCurrent: true, isASCIICapable: true,
                                       unshifted: [6: "z", 16: "y"], shifted: [:])
        let de = LayoutSnapshot.Layout(id: "de", name: "German", isCurrent: false, isASCIICapable: true,
                                       unshifted: [6: "y", 16: "z"], shifted: [:])
        let snapshot = LayoutSnapshot(layouts: [us, de])
        let cmdZ = KeyCombo(keyCode: 6, modifiers: [.command])
        let cmdY = KeyCombo(keyCode: 16, modifiers: [.command])
        let groups = ConflictAnalyzer.groups(from: [
            finding(xcode, .inApp, .accessibilityMenus, action: "Undo", combo: cmdZ, char: "z"),
            finding(raycast, .global, combo: cmdY),
        ], layouts: snapshot)
        let undo = groups.first { $0.combo == cmdZ }
        XCTAssertEqual(undo?.status, .layoutConflict)
        XCTAssertTrue(undo?.layoutNotes.contains { $0.isConflict && $0.layoutName == "German" } ?? false)
    }

    func testNonASCIILayoutAddsInformationalNote() {
        let ru = LayoutSnapshot.Layout(id: "ru", name: "Русская", isCurrent: false, isASCIICapable: false,
                                       unshifted: [8: "с"], shifted: [:])
        let cmdC = KeyCombo(keyCode: 8, modifiers: [.command])
        let groups = ConflictAnalyzer.groups(from: [finding(safari, .inApp, .accessibilityMenus, combo: cmdC, char: "c")],
                                             layouts: LayoutSnapshot(layouts: [ru]))
        XCTAssertEqual(groups[0].status, .none)
        XCTAssertEqual(groups[0].layoutNotes.count, 1)
        XCTAssertFalse(groups[0].layoutNotes[0].isConflict)
        XCTAssertTrue(groups[0].layoutNotes[0].message.contains("produces с"))
    }
}
