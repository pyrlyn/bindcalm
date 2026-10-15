# ShortcutClash

A macOS app that collects keyboard shortcuts from every source it can reach — system symbolic hotkeys,
running apps' menus, Services, custom App Shortcuts, third-party preference files and config files
(Karabiner-Elements, skhd, Hammerspoon, BetterTouchTool, Keyboard Maestro, Alfred, Raycast), Carbon
hotkey probing and live key capture — groups them by physical key combination and highlights real conflicts.

- Swift 6 toolchain, SwiftUI, Apple frameworks only (no third-party dependencies).
- macOS 14+, Apple Silicon. Built and verified on macOS 27.0.1 with Xcode 27.0 / Swift 6.4.
- **The UI is in Russian.** Code, comments and docs are in English.
- Implementation plan and milestones: [PLAN.md](PLAN.md).

## Build and run

```sh
swift build                  # debug build
swift build -c release       # release build
swift test                   # unit tests (parsers, grouping, conflict rules, layout analysis)
scripts/bundle.sh            # → dist/ShortcutClash.app (Info.plist + codesign)
open dist/ShortcutClash.app
```

`scripts/bundle.sh` signs ad-hoc unless `SHORTCUTCLASH_CODESIGN_IDENTITY` names a codesign identity
(for example `Developer ID Application: Name (TEAMID)`). A named identity is signed with a secure
timestamp, so Accessibility and Input Monitoring grants survive rebuilds. An unset, empty, or `-`
value keeps the ad-hoc signature (`codesign --sign - --timestamp=none`).

Headless modes (useful for scripting and for verifying the scanners without the GUI):

```sh
.build/debug/ShortcutClash --dump               # JSON report on stdout
.build/debug/ShortcutClash --dump --summary     # short human-readable summary
.build/debug/ShortcutClash --dump --methods symbolicHotKeys,accessibilityMenus
.build/debug/ShortcutClash --dump --all-methods # includes strategies that are off by default
.build/debug/ShortcutClash --probe-symbols      # which private symbols resolve via dlsym
```

When run from a terminal, TCC attributes the process to the terminal app, so the CLI inherits the
terminal's Accessibility / Input Monitoring grants. The bundled app has its own identity and starts
without any grants.

## How it works

Every detection method is an independent strategy behind one protocol:

```swift
public protocol HotKeyDiscoveryStrategy: Sendable {
    var id: DiscoveryMethod { get }
    var displayName: String { get }          // Russian, shown in the UI
    var summary: String { get }
    var defaultEnabled: Bool { get }
    var requiredPermission: PermissionKind? { get }
    var isLiveCapture: Bool { get }
    func discover(in context: DiscoveryContext) async throws -> [DiscoveredHotKey]
}
```

Each `DiscoveredHotKey` records the combo (virtual key code + modifiers, shown as `⌘⇧K`), the owner
(name, bundle ID, path), the method, a confidence level (`reliable` / `partial` / `heuristic`), a scope,
the action (menu title, hotkey name, preference key) and the exact source. Strategies run concurrently;
one failing or lacking permission never stops the scan. Each strategy can be toggled in the UI (the
choice is persisted) and every shortcut shows which method(s) found it.

### Scope and what counts as a conflict

| Scope | Meaning |
| --- | --- |
| `global` | Fires regardless of the frontmost app (symbolic hotkeys, Carbon hotkeys, Services, Apple menu). |
| `inApp` | Menu key equivalent that fires only while its app is frontmost. |
| `observed` | A key press seen in live capture. Evidence only, never a party in a conflict. |

`ConflictAnalyzer` groups claims by combo and marks:

- **Conflict** (red badge with the number of owners): two different owners where at least one is
  global — global vs global, or global vs any in-app shortcut of another app.
- **In-app duplicate**: one app binds the combo to several of its own menu items (optional, grey).
- **Layout conflict** (globe icon): a character-defined menu shortcut lands on a globally owned key in
  another enabled ASCII-capable layout (see *Layout analysis*).
- The same combo used inside several apps' menus is **not** a conflict: only the frontmost app gets it.
- Owners found by several methods are merged (macOS from the plist and from SkyLight is one owner).
- The anonymous owner from the Carbon probe corroborates a known global owner instead of opposing it.
- Disabled claims (e.g. a switched-off symbolic hotkey) are shown greyed and ignored.
- For a conflict, the detail panel names the likely winner. Claims are ranked by where they hook
  the keyboard, earliest first: HID remapper (Karabiner) → event tap (skhd, BetterTouchTool) →
  symbolic hotkey → Carbon hotkey (Alfred, Raycast, Keyboard Maestro, Hammerspoon `hs.hotkey`,
  the Carbon probe) → frontmost menu (Accessibility menus, App Shortcuts, Services). Two owners
  on the same earliest layer are a tie. Live observations and disabled claims do not win.
  Preference heuristics do not name a layer, so they lose to every known hook.

## Detection methods and their limitations

| # | Strategy (`id`) | Reads | Confidence | Needs |
| --- | --- | --- | --- | --- |
| 1 | `symbolicHotKeys` | `com.apple.symbolichotkeys` → `AppleSymbolicHotKeys` via CFPreferences | reliable | — |
| 2 | `skyLightSymbolic` | `CGSGetSymbolicHotKeyValue` / `CGSIsSymbolicHotKeyEnabled` (private, dlsym) | partial | — |
| 3 | `systemKeys` | `com.apple.HIToolbox`: fn/🌐 action, Caps Lock input switching | reliable | — |
| 4 | `userKeyEquivalents` | `NSUserKeyEquivalents` per app and in `NSGlobalDomain` | reliable | — |
| 5 | `services` | `NSServices` in app/.service/.workflow bundles + `pbs` → `NSServicesStatus` | reliable / partial | — |
| 6 | `preferencesScan` | `~/Library/Preferences/*.plist` (+ ByHost) for shortcut-library formats | partial / heuristic | — |
| 7 | `sandboxPreferences` | Same for `~/Library/Containers/*/Data/Library/Preferences` (off by default) | partial / heuristic | may trigger a TCC prompt |
| 8 | `accessibilityMenus` | Menu bars of running regular apps via AX | reliable | Accessibility |
| 9 | `carbonProbe` | `RegisterEventHotKey` probing of ~1,000 candidate combos | heuristic | — |
| 10 | `nsEventMonitor` | Global + local `NSEvent` key monitors (record mode) | heuristic | Accessibility (global) |
| 11 | `cgEventTap` | Listen-only session `CGEvent` tap (record mode) | heuristic | Input Monitoring |
| 12 | `karabiner` | `~/.config/karabiner/karabiner.json` complex modifications | partial | — |
| 13 | `skhd` | `~/.config/skhd/skhdrc` or `~/.skhdrc` | partial | — |
| 14 | `hammerspoon` | `hs.hotkey.bind` / `hs.hotkey.new` in `~/.hammerspoon` | partial | — |
| 15 | `betterTouchTool` | `.bttpreset` keyboard triggers | partial | — |
| 16 | `keyboardMaestro` | `Keyboard Maestro Macros.plist` hotkey triggers | partial | — |
| 17 | `alfred` | Workflow `info.plist` hotkeys and the launcher hotkey | partial | — |
| 18 | `raycast` | `hotkey` / `shortcut` fields in Raycast JSON and plist | partial | — |
| + | Layout analysis | TIS + `UCKeyTranslate` per enabled layout | — | — |

### 1. Symbolic hotkeys plist

Parses `parameters = (character, keyCode, modifierFlags)` entries; IDs are mapped to names from a
community-documented table (Spotlight 64/65, Mission Control 32–37, screenshots 28–31 and 184,
input sources 60/61, Spaces 79–82 and 118–133, etc.). Limitations: the plist only contains entries the
system or user has written — untouched defaults may be missing; there is no official ID list, so
unknown IDs are shown as `#id`; `type = button` (mouse) entries are ignored.

### 2. SkyLight symbolic hotkeys (private API)

Asks the WindowServer for the effective value of IDs 0–300, which includes defaults absent from the
plist. Read-only: the matching setters are resolved by the symbol probe but never called. The table
also holds internal entries (app switcher ⌘⇥, minimise ⌘M, window tiling with the Globe modifier, …)
whose meaning is undocumented; such IDs are shown but marked disabled so they never create
conflicts. Unmodified arrows/Help entries are skipped. Can disappear in any macOS release; a missing
symbol only marks the strategy unavailable.

### 3. fn/🌐 and Caps Lock

`AppleFnUsageType` (1 = change input source, 2 = emoji, 3 = dictation) and `TISRomanSwitchState`
(Caps Lock switches to ABC). Limitation: other single-key system actions (double-press dictation,
media keys) are not covered.

### 4. NSUserKeyEquivalents

Custom shortcuts from System Settings → Keyboard → Keyboard Shortcuts → App Shortcuts, read with
`CFPreferencesCopyValue` (not `CopyAppValue`, so global-domain entries are not repeated per app).
Bundle IDs come from `~/Library/Preferences` plus installed apps. Limitations: values for sandboxed
apps that live only in their container are not visible; the notation (`@$~^#` + character) is
character-based, so the key code is resolved through the ANSI table or the enabled layouts.

### 5. Services

User choices in `pbs` (`NSServicesStatus`, including Shortcuts/Automator quick actions stored as
`(null) - Name - runWorkflowAsService`) are reliable. `enabled_services_menu` decides whether the
shortcut is on; `enabled_context_menu` is used only when that key is absent. An entry that names a
shortcut but sets neither flag is **not** treated as enabled.

`NSServicesStatus` does not list the effective state of a service the user has never changed.
System Settings writes entries when the Services pane is opened or a checkbox is toggled, and there
is no other public pbs field for "the default is currently on". Defaults from `NSServices` →
`NSKeyEquivalent` in `/Applications`, `~/Applications`, `/System/Applications`,
`/System/Library/Services`, `/Library/Services`, `~/Library/Services` are therefore reported
**disabled** unless a status entry confirms them. A confirmed entry without its own
`key_equivalent` keeps the plist shortcut and the status enabled flag. Unconfirmed defaults stay
visible (partial, greyed) and do not create conflicts. The per-app Services submenu is skipped by
the AX strategy for the same reason.

### 6–7. Preference heuristics

Recognised formats: MASShortcut (`keyCode` + `modifierFlags`, also inside NSKeyedArchiver data),
ShortcutRecorder (`keyCode` + `modifierFlags` + `characters`), sindresorhus/KeyboardShortcuts (JSON
string `{"carbonKeyCode", "carbonModifiers"}`), generic `keyCode` + `modifiers` pairs (Carbon vs Cocoa
mask guessed by magnitude), symbolic-style `parameters` triples (e.g. Siri), and textual hotkeys
(`Option-Command-49`, `cmd+shift+k`, `⌘⇧K`) under keys named like *hotkey/shortcut*. Limitations:
a stored value says nothing about whether it is currently registered (the app may not run, or the
feature may be off) — such claims are downgraded to heuristic and annotated; libraries are also used
for in-app shortcuts, so a bare ⌘+key is classified as in-app; stale keys from uninstalled apps
appear. Preference domains that have a dedicated config-file strategy (Raycast, BetterTouchTool,
Keyboard Maestro, Alfred) are skipped here so they are not reported twice. Reading other apps'
containers can show the macOS "access data from other apps" prompt, so method 7 is opt-in.

### 12–18. Third-party config files

Each tool is its own strategy and its own toggle. The parsers are pure and covered by fixture tests;
the strategy only locates the file under the user's home directory and returns nothing when the tool
is not installed. A file that exists but cannot be parsed marks that strategy unavailable instead of
failing the scan. Claims are partial: the config can be present while the tool is not running.

- **Karabiner-Elements** reads complex modifications of the selected profile (the first profile if
  none is selected). A manipulator counts when `from.key_code` has a shortcut modifier or is an F-key.
  Simple one-key remaps are not shortcut claims. Karabiner is a HID remapper, so it sits above every
  other hook.
- **skhd** prefers `~/.config/skhd/skhdrc` and otherwise reads `~/.skhdrc`. `hyper` is ⌃⌥⇧⌘, `meh` is
  ⌃⌥⇧, `delete` is forward delete, and `0xNN` is a virtual key code. Blacklist blocks, mode
  declarations and the inside of a per-app process map are skipped. The binding itself is kept.
- **Hammerspoon** reads literal `hs.hotkey.bind` / `hs.hotkey.new` calls in `~/.hammerspoon` Lua files,
  skipping `Spoons`. Bindings assembled from variables are invisible. Comments are not reported.
- **BetterTouchTool** reads `.bttpreset` JSON (and `bttdata2` when it is JSON or a plist). Keyboard
  triggers use Cocoa modifier flags. `BT.G` is global; any other app group is in-app. The live SQLite
  database is not opened.
- **Keyboard Maestro** reads hotkey triggers from `Keyboard Maestro Macros.plist`. Modifiers are Carbon
  bits. A deactivated group or inactive macro is kept and marked disabled. `Targeting = Included` is
  in-app.
- **Alfred** reads `alfred.workflow.trigger.hotkey` objects (Cocoa `hotmod`, including the extra
  device-dependent bits Alfred stores) and `{key, mod, string}` dictionaries under `hotkey/prefs.plist`.
  Only the default `Alfred.alfredpreferences` location is used, not a synced copy. A disabled workflow
  is marked disabled; an empty hotkey is skipped.
- **Raycast** walks JSON and plist files under `~/.config/raycast` (not installed extension source),
  `~/Library/Application Support/com.raycast.macos` and `com.raycast.macos.plist` for `hotkey` /
  `shortcut` fields (a string such as `option+space`, or `{keyCode, modifiers}`). Shortcuts that
  Raycast keeps only in its private database are not visible.

### 8. Accessibility menus

Walks `AXMenuBar` of every running regular app with `AXUIElementCopyMultipleAttributeValues`
(`AXMenuItemCmdChar`, `AXMenuItemCmdVirtualKey`, `AXMenuItemCmdModifiers`, `AXMenuItemCmdGlyph`), a
1 s messaging timeout and an item budget. The first menu (Apple menu) is recorded once, as macOS and
global. While this method is enabled, switching apps re-reads only the newly frontmost app's menus
(`NSWorkspace.didActivateApplicationNotification`) and replaces that app's in-app claims. The Apple
menu is not walked again, a menu bar that cannot be read leaves the previous claims in place, and
the refresh does not prompt for Accessibility and does not run during a full scan. Gaining the
Accessibility grant refreshes the frontmost app once. Limitations: only running apps; only menus —
shortcuts handled in views/web content or by app-level key monitors are invisible; dynamic menus may
be empty until opened; the AX modifier
mask has **no fn/Globe bit**, so the window-tiling items macOS 15+ injects into every app
(Window → Move & Resize, Fill, Center — really 🌐⌃) would look like ⌃-combos and are skipped
(English/Russian/Ukrainian titles); status-bar extras are not opened.

### 9. Carbon probe

Registers each candidate (14 modifier sets × letters, digits, punctuation, Space, Return, Tab, Esc,
Delete, arrows, F1–F12) with `kEventHotKeyExclusive` and unregisters immediately;
`eventHotKeyExistsErr` means "taken". Observed on the test Mac: it detects the hotkeys the system
holds (⌘⇥, ⇧⌘⇥, ⌥⌘⎋, ⌃arrows, ⌃1), but **not** other apps' ordinary `RegisterEventHotKey`
registrations (a running app with a KeyboardShortcuts ⇧⌘Space hotkey was not detected). The owner
is never known. `GetEventHotKeyCount`/`GetEventHotKeyInfo` were never public API; they do not
resolve via dlsym on macOS 27.0.1, and even if present their signatures are undocumented, so the
app only reports their presence.

### 10–11. Live capture

Record mode installs a listen-only `CGEvent` tap at `cgSessionEventTap` plus global and local
`NSEvent` monitors and correlates the three by combo within 350 ms. Only shortcut-like presses
(⌘/⌃/⌥ or F-keys) are recorded — ordinary typing is never logged. Interpretation: seen by the local
monitor → reached this window; seen by the global monitor → delivered to the frontmost app; seen
only by the tap → probably consumed by a global hotkey before delivery. Each press is shown with the
frontmost app (`NSWorkspace.frontmostApplication` and the AX focused app) and cross-referenced with
the registry. Limitations: heuristic; secure input (password fields, Terminal "Secure Keyboard
Entry") blinds all taps — the UI warns via `IsSecureEventInputEnabled()`; Karabiner-style remappers
act below the session tap; global key monitors require Accessibility, the tap requires Input
Monitoring.

### Layout analysis

`LayoutService` (main thread only — Text Input Sources must not be called off the main queue)
captures every enabled keyboard layout with `TISCreateInputSourceList` and translates key codes with
`UCKeyTranslate`. The detail panel shows the character each combo produces in each layout. For
character-defined claims (menus, App Shortcuts, Services) it computes the key code the same
character has in other ASCII-capable layouts and flags a **layout conflict** if that key is globally
owned (e.g. QWERTZ swaps Y/Z). For non-Latin layouts (Russian, Ukrainian) it adds a note that apps
which match characters instead of key codes may misfire.

## Permissions

- **Accessibility** (menus, global NSEvent monitor): checked with `AXIsProcessTrusted()`; the system
  prompt appears only when the user presses "Запросить".
- **Input Monitoring** (CGEvent tap): `CGPreflightListenEventAccess()`; `CGRequestListenEventAccess()`
  only on request.
- Both statuses are polled every 2 s (TCC does not notify apps) and shown at the bottom of the sidebar
  with buttons that open the right System Settings pane.
- By default the bundle is ad-hoc signed: TCC keys grants to the code hash, so every rebuild looks
  like a new app and grants may need to be re-approved. Set `SHORTCUTCLASH_CODESIGN_IDENTITY` when
  running `scripts/bundle.sh` to sign with a Developer ID (or another stable identity) instead.
- The app is not sandboxed (it must read other apps' preferences and walk their menus).

## Research: other macOS methods

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

Symbol probe on the development Mac (`ShortcutClash --probe-symbols`): found — `CopySymbolicHotKeys`
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

## Project files

`AGENTS.md` (agent rules), `PLAN.md` (plan, active tasks and milestones), `todo.md`, `done.md`,
`roadmap.md`, `ideas.md`, `toolchain.md`.
