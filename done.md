# Done

### D1. Initial implementation

Swift package with `BindcalmCore`, the SwiftUI app and tests. Eleven independent detection
strategies behind `HotKeyDiscoveryStrategy` (symbolic hotkeys plist, SkyLight symbolic hotkeys,
fn/Caps Lock, NSUserKeyEquivalents, Services, preference heuristics, sandbox preferences,
Accessibility menus, Carbon probe, NSEvent monitors, CGEvent tap), conflict and layout analysis,
Russian UI with per-method toggles, filters, search, detail panel, live capture, diagnostics and JSON
export, headless `--dump` / `--probe-symbols`, `scripts/bundle.sh`, README with method limitations
and a research section (milestones M1–M8 in `PLAN.md`).

### D2. Config-file parsers

Seven independent strategies, each with a pure parser and fixture tests, registered in
`StrategyRegistry.all` so the methods popover shows a toggle: Karabiner-Elements, skhd, Hammerspoon,
BetterTouchTool, Keyboard Maestro, Alfred and Raycast. Missing configs produce no claims. A present
file that cannot be parsed marks that strategy unavailable. Preference domains owned by these
strategies are skipped by the heuristic plist scan.

### D3. Services defaults stay disabled until pbs confirms them

`NSServicesStatus` does not publish the effective state of a service the user has never changed.
Info.plist defaults are reported disabled unless a status entry confirms them.
`enabled_services_menu` is the keyboard-shortcut gate; a status entry with neither enabled flag is
not treated as on. A confirmed entry without its own key equivalent keeps the plist shortcut.

### D4. Which shortcut wins

`ShortcutRanking` orders enabled claims by hook layer: HID remapper, event tap, symbolic hotkey,
Carbon hotkey, frontmost menu. The detail panel shows the winner and a Russian explanation. Several
owners on the earliest layer are a tie. Disabled claims, live observations and unknown-layer
heuristics do not beat a known hook.

### D5. Watch mode for the frontmost app's menus

`NSWorkspace.didActivateApplicationNotification` re-reads only the activated app's Accessibility
menus and `MenuClaimRefresh` replaces that owner's in-app menu claims. The Apple menu stays as
recorded by the last full scan. An unreadable menu bar keeps the previous claims. The refresh does
not prompt for Accessibility, does not run while a full scan is in progress, and runs once for the
frontmost app when the Accessibility grant appears.

### D6. Stable code signature

`scripts/bundle.sh` signs with `BINDCALM_CODESIGN_IDENTITY` and a secure timestamp when that
variable names a codesign identity, so TCC grants survive rebuilds. An unset, empty, or `-` value
falls back to ad-hoc `codesign --force --sign - --timestamp=none`.

### D7. Design v3 in SwiftUI

The v3 "minimal glass" design from `design/` is the app's UI: `Theme.swift` holds the tokens as
dynamic light/dark colours plus an `AppearanceMode` override, `Components.swift` the soft buttons,
fields, switches, menus, badges and the shared `EmptyStateView`. Every screen and empty state is
implemented, the UI and strategy display strings are English, and Reduce Transparency / Reduce
Motion have fallbacks. `BINDCALM_PREVIEW=<scenario>` shows fixtures instead of a real scan for
screenshots. Ported from the pre-rename `feat/design-v3` branch onto the Bindcalm package.
