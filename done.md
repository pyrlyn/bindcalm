# Done

### D1. Initial implementation

Swift package with `ShortcutClashCore`, the SwiftUI app and tests. Eleven independent detection
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
