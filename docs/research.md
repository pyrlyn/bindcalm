# Research: other macOS methods

Status legend: ✅ works, ⚠️ works with caveats, ❌ does not help. "Verified" means checked on the
development Mac (macOS 27.0.1, arm64); Sonoma (14) / Sequoia (15) status is inferred from API
availability and is unverified unless stated.

| Method | Status | Notes |
| --- | --- | --- |
| `CGSGetSymbolicHotKeyValue` / `CGSIsSymbolicHotKeyEnabled` (SkyLight) | ✅ verified, used | Effective system hotkeys incl. defaults. Private. |
| `SLSGetSymbolicHotKeyValue` / `SLSIsSymbolicHotKeyEnabled` | ✅ resolves | SLS-prefixed aliases; used as fallback. |
| `CopySymbolicHotKeys` (HIToolbox) | ⚠️ resolves, not used | Undocumented signature; the SkyLight getters cover the same data safely. |
| `CGSGetGlobalHotKeyOperatingMode` / `CGSSetGlobalHotKeyOperatingMode` | ⚠️ resolves, never called | Setter disables all hotkeys for a connection (that is how recorders let you press a taken combo); not a detection method. |
| `_CGSDefaultConnection`, `CGSMainConnectionID` | ✅ resolve | Only needed for the operating-mode calls above. |
| `GetEventHotKeyCount` / `GetEventHotKeyInfo` | ❌ not present | Never public; do not resolve on macOS 27.0.1. |
| `RegisterEventHotKey` probing | ⚠️ verified, used | Sees system-held hotkeys only, owner unknown (see method 9). |
| `AXIsProcessTrusted` + `AXUIElementCopyAttributeValue` menu walk | ✅ verified, used | Best source for in-app shortcuts; no fn bit. |
| Focused app: `NSWorkspace.frontmostApplication`, `AXFocusedApplication` on `AXUIElementCreateSystemWide()` | ✅ verified, used | Both used in live capture; AX needs Accessibility and may differ for panels/agents. |
| `NSWorkspace.didActivateApplicationNotification` | ✅ used | Re-reads the activated app's menus so in-app claims stay current without a manual rescan (method 8). |
| TIS: `TISCopyCurrentKeyboardInputSource`, `TISCopyCurrentKeyboardLayoutInputSource`, `TISCreateInputSourceList` | ✅ verified, used | Main thread only. |
| Per-app input source ("automatically switch to a document's input source") | ⚠️ | Only the on/off flag is readable (`com.apple.HIToolbox` → `AppleGlobalTextInputProperties` → `TextInputGlobalPropertyPerContextInput`); which layout each app/document uses is not exposed by a public API. |
| `UCKeyTranslate` key code ↔ character | ✅ verified, used | Basis of the layout analysis. |
| Character vs key code matching | ⚠️ | Carbon/symbolic hotkeys match key codes; menu key equivalents are characters. With a non-Latin layout active, ⌘+key C produces "с"; Cocoa menus fall back to the ASCII-capable layout so ⌘C still works, but apps that compare characters (some cross-platform toolkits) may not — a user-visible conflict that is layout-dependent. |
| `IOHIDManager` low-level capture | ⚠️ | Sees raw HID usages below the WindowServer (so even before session taps and Karabiner's virtual device distinction), needs Input Monitoring. It cannot tell who consumes a combo, so it adds little over the CGEvent tap for conflict detection. Not implemented. |
| LaunchServices: `NSWorkspace.urlForApplication(withBundleIdentifier:)`, `urlsForApplications(withBundleIdentifier:)`, `LSCopyApplicationURLsForBundleIdentifier` | ✅ used (first) | Owner resolution (name, path, icon). The plural variants help when several copies of an app are installed. |
| `SMAppService` | ❌ irrelevant | Manages login items/daemons; has nothing to do with hotkeys. |
| Dock / Mission Control prefs (`com.apple.dock`) | ❌ | Hot corners and gestures, not keyboard shortcuts; Mission Control keys are symbolic hotkeys (methods 1–2). |
| Config-file parsers (Karabiner `karabiner.json`, skhd, Hammerspoon, BetterTouchTool, Keyboard Maestro, Alfred, Raycast) | ⚠️ not implemented | Precise for those tools; each needs its own parser. HotkeyClash (below) implements several. |
| `kAXMenuItemCmdChar` on status-bar extras / web content `AXKeyShortcutsValue` | ⚠️ | Requires opening menus or walking full window trees; expensive and intrusive. |

Symbol probe on the development Mac (`Bindcalm --probe-symbols`): found — `CopySymbolicHotKeys`
(HIToolbox), `CGSGetSymbolicHotKeyValue`, `CGSIsSymbolicHotKeyEnabled`, `CGSSetSymbolicHotKeyEnabled`,
`SLSGetSymbolicHotKeyValue`, `SLSIsSymbolicHotKeyEnabled`, `_CGSDefaultConnection`,
`CGSMainConnectionID`, `CGSGetGlobalHotKeyOperatingMode`, `CGSSetGlobalHotKeyOperatingMode` (SkyLight),
`IsSecureEventInputEnabled`, `RegisterEventHotKey` (HIToolbox); missing — `GetEventHotKeyCount`,
`GetEventHotKeyInfo`.

### Example 1: effective system hotkeys through SkyLight

```swift
import Darwin

typealias GetValue = @convention(c) (Int32, UnsafeMutablePointer<UInt16>?,
                                     UnsafeMutablePointer<UInt16>?, UnsafeMutablePointer<UInt64>?) -> Int32
typealias IsEnabled = @convention(c) (Int32) -> Bool

let rtldDefault = UnsafeMutableRawPointer(bitPattern: -2)
if let g = dlsym(rtldDefault, "CGSGetSymbolicHotKeyValue"),
   let e = dlsym(rtldDefault, "CGSIsSymbolicHotKeyEnabled") {
    let getValue = unsafeBitCast(g, to: GetValue.self)
    let isEnabled = unsafeBitCast(e, to: IsEnabled.self)
    var char: UInt16 = 0, keyCode: UInt16 = 0, mods: UInt64 = 0   // CGSModifierFlags: Cocoa-style mask
    if getValue(64, &char, &keyCode, &mods) == 0 {                // 64 = Spotlight
        print("Spotlight: keyCode \(keyCode) mods \(String(mods, radix: 16)) enabled \(isEnabled(64))")
    }
}
```

### Example 2: menu shortcuts of a running app via Accessibility

```swift
import ApplicationServices

func menuShortcuts(pid: pid_t) -> [(title: String, char: String?, mods: Int, glyph: Int)] {
    guard AXIsProcessTrusted() else { return [] }
    let attrs = ["AXTitle", "AXMenuItemCmdChar", "AXMenuItemCmdModifiers", "AXMenuItemCmdGlyph", "AXChildren"] as CFArray
    var out: [(String, String?, Int, Int)] = []
    func walk(_ el: AXUIElement) {
        var values: CFArray?
        guard AXUIElementCopyMultipleAttributeValues(el, attrs, AXCopyMultipleAttributeOptions(), &values) == .success,
              let v = values as? [AnyObject] else { return }
        func clean(_ x: AnyObject) -> AnyObject? { CFGetTypeID(x) == AXValueGetTypeID() ? nil : x }  // missing → AXError
        let char = clean(v[1]) as? String, glyph = (clean(v[3]) as? Int) ?? 0
        if (char?.isEmpty == false) || glyph > 0 {
            out.append((clean(v[0]) as? String ?? "", char, (clean(v[2]) as? Int) ?? 0, glyph))  // mods: 0 == ⌘
        }
        (clean(v[4]) as? [AXUIElement])?.forEach(walk)
    }
    let app = AXUIElementCreateApplication(pid)
    var bar: CFTypeRef?
    if AXUIElementCopyAttributeValue(app, "AXMenuBar" as CFString, &bar) == .success { walk(bar as! AXUIElement) }
    return out
}
```

### Example 3: which character a key code produces in each enabled layout

```swift
import Carbon

@MainActor func characters(forKeyCode keyCode: UInt16) -> [String: String] {
    let filter = [kTISPropertyInputSourceType: kTISTypeKeyboardLayout] as CFDictionary
    let sources = TISCreateInputSourceList(filter, false).takeRetainedValue() as! [TISInputSource]
    var result: [String: String] = [:]
    for source in sources {
        guard let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData),
              let nameRaw = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) else { continue }
        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue()
        let name = Unmanaged<CFString>.fromOpaque(nameRaw).takeUnretainedValue() as String
        var dead: UInt32 = 0, length = 0, chars = [UniChar](repeating: 0, count: 4)
        CFDataGetBytePtr(data).withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) {
            _ = UCKeyTranslate($0, keyCode, UInt16(kUCKeyActionDown), 0, UInt32(LMGetKbdType()),
                               OptionBits(kUCKeyTranslateNoDeadKeysMask), &dead, 4, &length, &chars)
        }
        result[name] = String(utf16CodeUnits: chars, count: length)   // keyCode 8: "c" in ABC, "с" in Russian
    }
    return result
}
```

### Sources (checked 2026-10-04)

- Apple, `NSEvent.addGlobalMonitorForEvents(matching:handler:)` — key events require Accessibility;
  monitors only observe, never prevent delivery:
  https://developer.apple.com/documentation/appkit/nsevent/addglobalmonitorforevents(matching:handler:)
- Apple, `CGEvent.tapCreate(tap:place:options:eventsOfInterest:callback:userInfo:)` — HID-level taps
  need root; session taps get key events only with the required access:
  https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:)
- NUIKit/CGSInternal `CGSHotKeys.h` — signatures of `CGSGetSymbolicHotKeyValue`,
  `CGSIsSymbolicHotKeyEnabled`, `CGS{Get,Set}GlobalHotKeyOperatingMode`, symbolic hotkey IDs and
  `CGSModifierFlags`: https://github.com/NUIKit/CGSInternal/blob/master/CGSHotKeys.h
- sindresorhus/KeyboardShortcuts `Shortcut.swift` — storage as `carbonKeyCode`/`carbonModifiers`,
  stripping of the synthesized fn bit, and "`TISGetInputSourceProperty` crashes if called on a
  non-main thread": https://github.com/sindresorhus/KeyboardShortcuts/blob/main/Sources/KeyboardShortcuts/Shortcut.swift
- Wunderlandmedia/HotkeyClash — an existing open-source app with a similar goal (AX menus, symbolic
  hotkeys, Karabiner/skhd and other config parsers, "which layer wins" model):
  https://github.com/wunderlandmedia/hotkeyclash

Statements in this section without a source (e.g. Carbon probe behaviour, AX lacking an fn bit,
tiling items) are observations on the development Mac.
