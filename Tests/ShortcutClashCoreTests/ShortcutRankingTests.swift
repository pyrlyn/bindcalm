import XCTest
@testable import ShortcutClashCore

final class ShortcutRankingTests: XCTestCase {
    let combo = KeyCombo(keyCode: 49, modifiers: [.command])
    let karabiner = HotKeyOwner(name: "Karabiner-Elements", bundleID: "org.pqrs.Karabiner-Elements")
    let skhd = HotKeyOwner(name: "skhd", bundleID: "com.koekeishiya.skhd")
    let raycast = HotKeyOwner(name: "Raycast", bundleID: "com.raycast.macos")
    let alfred = HotKeyOwner(name: "Alfred", bundleID: "com.runningwithcrayons.Alfred")
    let xcode = HotKeyOwner(name: "Xcode", bundleID: "com.apple.dt.Xcode")

    func claim(_ owner: HotKeyOwner, _ method: DiscoveryMethod, scope: HotKeyScope = .global,
               enabled: Bool = true) -> DiscoveredHotKey {
        DiscoveredHotKey(combo: combo, owner: owner, method: method, confidence: .partial, scope: scope,
                         action: method.rawValue, enabled: enabled, source: method.rawValue)
    }

    func testLayersFollowTheHookOrder() {
        XCTAssertLessThan(ShortcutRanking.layer(of: .karabiner), ShortcutRanking.layer(of: .skhd))
        XCTAssertLessThan(ShortcutRanking.layer(of: .skhd), ShortcutRanking.layer(of: .symbolicHotKeys))
        XCTAssertLessThan(ShortcutRanking.layer(of: .symbolicHotKeys), ShortcutRanking.layer(of: .alfred))
        XCTAssertLessThan(ShortcutRanking.layer(of: .carbonProbe), ShortcutRanking.layer(of: .accessibilityMenus))
        XCTAssertEqual(ShortcutRanking.layer(of: .hammerspoon), .carbonHotkey)
        XCTAssertEqual(ShortcutRanking.layer(of: .betterTouchTool), .eventTap)
        XCTAssertEqual(ShortcutRanking.layer(of: .services), .frontmostMenu)
        XCTAssertEqual(ShortcutRanking.layer(of: .preferencesScan), .unknown)
    }

    func testEarlierLayerWinsTheConflict() {
        let ranking = ShortcutRanking.winner(in: [
            claim(xcode, .accessibilityMenus, scope: .inApp),
            claim(raycast, .raycast),
            claim(.macOS, .symbolicHotKeys),
            claim(karabiner, .karabiner),
            claim(skhd, .skhd),
        ])
        XCTAssertEqual(ranking?.isTie, false)
        XCTAssertEqual(ranking?.layer, .hidRemapper)
        XCTAssertEqual(ranking?.owners, [karabiner])
        XCTAssertTrue(ranking?.explanation.contains("Karabiner-Elements") ?? false)
        XCTAssertTrue(ranking?.explanation.contains("HID") ?? false)
    }

    func testSameLayerDifferentOwnersIsATie() {
        let ranking = ShortcutRanking.winner(in: [
            claim(raycast, .raycast),
            claim(alfred, .alfred),
            claim(xcode, .accessibilityMenus, scope: .inApp),
        ])
        XCTAssertEqual(ranking?.isTie, true)
        XCTAssertEqual(ranking?.layer, .carbonHotkey)
        XCTAssertEqual(Set(ranking?.owners.map(\.key) ?? []), [raycast.key, alfred.key])
        XCTAssertTrue(ranking?.explanation.contains("undetermined") ?? false)
    }

    func testSameOwnerOnOneLayerIsNotATie() {
        let ranking = ShortcutRanking.winner(in: [
            claim(.macOS, .symbolicHotKeys),
            claim(.macOS, .skyLightSymbolic),
            claim(xcode, .userKeyEquivalents, scope: .inApp),
        ])
        XCTAssertEqual(ranking?.isTie, false)
        XCTAssertEqual(ranking?.layer, .symbolicHotkey)
        XCTAssertEqual(ranking?.owners, [.macOS])
    }

    func testDisabledAndObservedClaimsDoNotWin() {
        let ranking = ShortcutRanking.winner(in: [
            claim(karabiner, .karabiner, enabled: false),
            claim(skhd, .cgEventTap, scope: .observed),
            claim(xcode, .accessibilityMenus, scope: .inApp),
        ])
        XCTAssertEqual(ranking?.layer, .frontmostMenu)
        XCTAssertEqual(ranking?.owners, [xcode])
    }

    func testUnknownLayerLosesToAMenu() {
        let ranking = ShortcutRanking.winner(in: [
            claim(raycast, .preferencesScan),
            claim(xcode, .accessibilityMenus, scope: .inApp),
        ])
        XCTAssertEqual(ranking?.layer, .frontmostMenu)
        XCTAssertEqual(ranking?.owners, [xcode])
    }

    func testNoActiveClaimsHasNoWinner() {
        XCTAssertNil(ShortcutRanking.winner(in: [claim(raycast, .raycast, enabled: false)]))
        XCTAssertNil(ShortcutRanking.winner(in: []))
    }
}