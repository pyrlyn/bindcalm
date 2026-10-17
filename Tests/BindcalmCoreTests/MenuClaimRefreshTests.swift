import XCTest
@testable import BindcalmCore

final class MenuClaimRefreshTests: XCTestCase {
    let combo = KeyCombo(keyCode: 0, modifiers: [.command])
    let xcode = HotKeyOwner(name: "Xcode", bundleID: "com.apple.dt.Xcode")
    let safari = HotKeyOwner(name: "Safari", bundleID: "com.apple.Safari")

    func claim(_ owner: HotKeyOwner, _ method: DiscoveryMethod, scope: HotKeyScope = .inApp,
               action: String) -> DiscoveredHotKey {
        DiscoveredHotKey(combo: combo, owner: owner, method: method, confidence: .reliable, scope: scope,
                         action: action, source: action)
    }

    func testApplyReplacesOnlyThatAppsInAppMenus() {
        let stale = claim(xcode, .accessibilityMenus, action: "File → Old")
        let safariMenu = claim(safari, .accessibilityMenus, action: "File → New Window")
        let apple = claim(.macOS, .accessibilityMenus, scope: .global, action: "Apple → About")
        let xcodeKeys = claim(xcode, .userKeyEquivalents, action: "NSUserKeyEquivalents")
        let fresh = claim(xcode, .accessibilityMenus, action: "File → New")
        let stranger = claim(safari, .accessibilityMenus, action: "must not land on Xcode")

        let updated = MenuClaimRefresh.apply(ownerKey: xcode.key, fresh: [fresh, stranger],
                                              to: [stale, safariMenu, apple, xcodeKeys])

        XCTAssertEqual(updated.filter { $0.owner.key == xcode.key && $0.method == .accessibilityMenus }.map(\.action),
                       ["File → New"])
        XCTAssertTrue(updated.contains(safariMenu))
        XCTAssertTrue(updated.contains(apple))
        XCTAssertTrue(updated.contains(xcodeKeys))
        XCTAssertFalse(updated.contains(stranger))
        XCTAssertFalse(updated.contains(stale))
    }

    func testEmptyReadClearsThatAppsMenus() {
        let stale = claim(xcode, .accessibilityMenus, action: "File → Old")
        let safariMenu = claim(safari, .accessibilityMenus, action: "File → New Window")
        let updated = MenuClaimRefresh.apply(ownerKey: xcode.key, fresh: [], to: [stale, safariMenu])
        XCTAssertEqual(updated, [safariMenu])
    }
}
