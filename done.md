# Done

### D1. Initial implementation

Swift package with `ShortcutClashCore`, the SwiftUI app and tests. Eleven independent detection
strategies behind `HotKeyDiscoveryStrategy` (symbolic hotkeys plist, SkyLight symbolic hotkeys,
fn/Caps Lock, NSUserKeyEquivalents, Services, preference heuristics, sandbox preferences,
Accessibility menus, Carbon probe, NSEvent monitors, CGEvent tap), conflict and layout analysis,
Russian UI with per-method toggles, filters, search, detail panel, live capture, diagnostics and JSON
export, headless `--dump` / `--probe-symbols`, `scripts/bundle.sh`, README with method limitations
and a research section (milestones M1–M8 in `PLAN.md`).
