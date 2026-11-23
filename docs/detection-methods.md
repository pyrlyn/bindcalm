# Detection methods and their limitations

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
