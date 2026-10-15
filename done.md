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
