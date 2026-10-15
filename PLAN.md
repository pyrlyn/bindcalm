# ShortcutClash

GitHub: https://github.com/listepo/ShortcutClash

A macOS app (Swift, SwiftUI, Apple frameworks only, Russian UI) that finds keyboard shortcut conflicts
between apps using every available detection method and highlights them.

> This file is both the active-task plan (`plan.md` in the shared rules; macOS file systems are
> case-insensitive, so there is a single `PLAN.md`) and the detailed implementation plan.

| # | Status | Priority | Complexity | Readiness | Agent |
| --- | --- | --- | --- | --- | --- |
| T1 | todo | P1 | 3 | 0% | |
| T2 | done | P2 | 3 | 100% | |
| T3 | todo | P2 | 2 | 0% | |
| T4 | todo | P2 | 4 | 0% | |
| T5 | todo | P3 | 2 | 0% | |
| T6 | todo | P3 | 3 | 0% | |

### T1. Verify the GUI flows with permissions granted

The bundled app was launched and its window rendered, but its own Accessibility / Input Monitoring
grants were never given (by design during development). Done when, with grants given by the
creator: the AX strategy fills in-app shortcuts in the GUI, record mode shows tap/global/local flags
correctly for a known global hotkey (e.g. ⌘Space) and for a free combo, and the permission bar
updates without restarting.

### T2. Config-file parsers for hotkey tools

Add strategies for Karabiner-Elements (`~/.config/karabiner/karabiner.json`), skhd, Hammerspoon,
BetterTouchTool, Keyboard Maestro, Alfred and Raycast, each a separate `HotKeyDiscoveryStrategy` with
fixture-based tests. Done when each parser has tests and appears as a toggle.

### T3. Reduce Services false positives

Default `NSServices` shortcuts are reported as partial global claims even if the service is disabled.
Investigate whether `pbs` exposes the effective enabled state for defaults (e.g. `NSServicesStatus`
entries written after the user opens the Services settings) and, if not, mark defaults disabled
unless confirmed. Done when the Services strategy's claims match System Settings → Keyboard →
Keyboard Shortcuts → Services on the test Mac.

### T4. "Which shortcut wins" model

Rank claims by the layer where they hook the keyboard (HID remapper → event tap → symbolic hotkey →
Carbon hotkey → frontmost menu) and show the likely winner per conflict. Done when the detail panel
shows a winner with an explanation and tests cover the ranking.

### T5. Watch mode

Use `NSWorkspace.didActivateApplicationNotification` to re-scan the frontmost app's menu when it
changes and keep the list current. Done when switching apps updates in-app claims without a manual
rescan.

### T6. Stable code signature

Document or script signing with a Developer ID (when available) so TCC grants survive rebuilds.
Done when `scripts/bundle.sh` accepts an identity via an environment variable and falls back to
ad-hoc signing.

## Implementation plan

### Architecture

- **Package layout.** `Package.swift` (tools 6.0, macOS 14, Swift 5 language mode because the
  AX/Carbon/CGEvent C APIs lack concurrency annotations). Targets:
  - `ShortcutClashCore` (library): models, parsers, strategies, analysis, layout, live capture.
  - `ShortcutClash` (executable): SwiftUI app + headless CLI (`--dump`, `--summary`, `--probe-symbols`).
  - `ShortcutClashCoreTests`: XCTest suites for pure logic.
- **Model.**
  - `ModifierSet` — one option set with converters for Carbon masks, Cocoa/CGEvent flags,
    `kAXMenuItemCmdModifiers` (⌘ implied unless bit 8) and Apple display order `fn ⌃⌥⇧⌘`.
  - `KeyCombo` — virtual key code + modifiers; drops the fn flag that Cocoa synthesizes for arrows and
    F-keys so one physical combo is one group.
  - `HotKeyOwner` — name, bundle ID, path, kind (`app`, `system`, `allApps`, `unknown`) and a merge key.
  - `DiscoveredHotKey` — combo, owner, method, confidence, scope (`global`/`inApp`/`observed`), action,
    enabled, source, defining character (for layout analysis).
- **Strategy protocol.** `HotKeyDiscoveryStrategy` (id, Russian display name and summary, default
  enabled, required permission, live flag, `discover(in:) async throws`). `StrategyRegistry.all` lists
  them; `DiscoveryContext` carries the layout snapshot, owner resolver and home directory.
- **Engine.** `ScanEngine.run` executes enabled strategies in a task group, maps `DiscoveryError`
  to `needsPermission` / `unavailable`, records counts and durations, de-duplicates by id.
- **Analysis.** `ConflictAnalyzer` groups by combo and assigns `conflict` / `layoutConflict` /
  `inAppDuplicate` / `none` (rules in README). `LayoutAnalyzer` adds per-layout notes.
- **Owner resolution.** `OwnerResolver` (LaunchServices via `NSWorkspace`, cached, thread-safe).

### Strategy modules

| Module | File | Key APIs |
| --- | --- | --- |
| Symbolic hotkeys plist | `SymbolicHotKeysPlistStrategy.swift` | `CFPreferencesCopyAppValue` |
| SkyLight symbolic hotkeys | `SkyLightSymbolicStrategy.swift` | `dlsym`: `CGSGetSymbolicHotKeyValue`, `CGSIsSymbolicHotKeyEnabled` |
| fn/🌐 and Caps Lock | `SystemKeysStrategy.swift` | `com.apple.HIToolbox` prefs |
| App Shortcuts | `UserKeyEquivalentsStrategy.swift` | `CFPreferencesCopyValue(NSUserKeyEquivalents)` |
| Services | `ServicesStrategy.swift` | Info.plist `NSServices`, `pbs` `NSServicesStatus` |
| Preference heuristics | `PreferencesScanStrategy.swift` + `ShortcutFormatDetector.swift` | `PropertyListSerialization` |
| Karabiner-Elements | `ConfigFileStrategies.swift` + `KarabinerParser.swift` | `karabiner.json` complex modifications |
| skhd | `ConfigFileStrategies.swift` + `SkhdParser.swift` | `~/.config/skhd/skhdrc`, `~/.skhdrc` |
| Hammerspoon | `ConfigFileStrategies.swift` + `HammerspoonParser.swift` | `hs.hotkey.bind` / `new` in `~/.hammerspoon` |
| BetterTouchTool | `ConfigFileStrategies.swift` + `BetterTouchToolParser.swift` | `.bttpreset` JSON |
| Keyboard Maestro | `ConfigFileStrategies.swift` + `KeyboardMaestroParser.swift` | `Keyboard Maestro Macros.plist` |
| Alfred | `ConfigFileStrategies.swift` + `AlfredParser.swift` | workflow `info.plist`, hotkey prefs |
| Raycast | `ConfigFileStrategies.swift` + `RaycastParser.swift` | JSON/plist `hotkey` fields |
| Accessibility menus | `AccessibilityMenuStrategy.swift` | `AXUIElementCopyMultipleAttributeValues` |
| Carbon probe | `CarbonProbeStrategy.swift` | `RegisterEventHotKey` / `UnregisterEventHotKey` |
| Live capture | `Live/LiveCapture.swift` | `CGEvent.tapCreate`, `NSEvent` monitors |
| Private symbol probe | `System/PrivateSymbols.swift` | `dlopen` / `dlsym` / `dladdr` |

### SwiftUI UI (Russian)

- `NavigationSplitView`: sidebar with the grouped list, detail panel per combo.
- Sidebar: "Только конфликты" toggle, method and app pickers, search (combo, app, bundle ID, action),
  counters, red badge with the number of active owners for conflicts, globe icon for layout
  conflicts, grey icon for in-app duplicates, method badges per row, permission bar at the bottom.
- Detail: combo, status and explanation, "Обнаружено методами", key code/modifiers, character per
  enabled layout, layout notes, one card per owner (icon, bundle ID, path) with every claim (method,
  confidence, scope, enabled, selectable source), and live observations for this combo.
- Toolbar: rescan, start/stop live capture, capture log, request Accessibility, methods popover
  (per-method toggle persisted in `UserDefaults`, status/count/duration, layout analysis toggle,
  duplicates toggle), diagnostics sheet (permissions, layouts, symbol probe, strategy results),
  JSON export.

### Layout handling

- `LayoutService` (main actor) snapshots enabled keyboard layouts (`TISCreateInputSourceList`,
  `kTISPropertyUnicodeKeyLayoutData`) and builds key code → character tables with `UCKeyTranslate`.
- Character-defined claims are normalised to key codes through the ANSI table, then the layouts.
- `LayoutAnalyzer` flags character claims that land on globally owned keys in other ASCII-capable
  layouts and annotates non-Latin layouts.

### Permissions and TCC

- Accessibility: `AXIsProcessTrusted` for status; prompt only on explicit request. Needed by the AX
  strategy and the global NSEvent monitor.
- Input Monitoring: `CGPreflightListenEventAccess` / `CGRequestListenEventAccess`. Needed by the tap.
- Statuses polled every 2 s; buttons open `x-apple.systempreferences:` panes.
- Ad-hoc signature → grants are bound to the code hash and reset on rebuild (T6).
- Secure input detection via `IsSecureEventInputEnabled`.

### Build and bundle

- `swift build` / `swift build -c release`; `scripts/bundle.sh [release|debug]` copies the binary and
  `Resources/Info.plist` (LSUIElement false, Russian development region,
  `NSAppleEventsUsageDescription`) into `dist/ShortcutClash.app` and signs it with `codesign -s -`.

### Tests

XCTest suites: modifier conversions and display; key-equivalent, glyph and hotkey-string parsing;
symbolic hotkeys and Services parsing; shortcut-format detection (MASShortcut, ShortcutRecorder,
KeyboardShortcuts JSON, archived data, parameters, strings); conflict rules; layout conflicts;
AX tiling filter; preference scope heuristic; config-file parsers (Karabiner, skhd, Hammerspoon,
BetterTouchTool, Keyboard Maestro, Alfred, Raycast) and their registry toggles.

### Limitations

See README → "Detection methods and their limitations" and "Research".

### Milestones

| Milestone | Status |
| --- | --- |
| M1. Package skeleton, models, strategy protocol, engine | done |
| M2. Registry strategies: symbolic plist, SkyLight, fn/Caps Lock, App Shortcuts, Services, preference heuristics | done |
| M3. Accessibility menu strategy with permission handling and tiling filter | done |
| M4. Carbon probe and private symbol probe | done |
| M5. Live capture (CGEvent tap + NSEvent monitors) with correlation | done |
| M6. Conflict analysis and layout analysis | done |
| M7. SwiftUI UI, per-method toggles, filters, export | done |
| M8. CLI `--dump`, bundle script, unit tests, README research | done |
| M9. GUI verification with grants | todo (T1) |
| M10. Config-file parsers | done (T2) |
| M11. Services accuracy, winner model, watch mode, stable signing | todo (T3–T6) |
