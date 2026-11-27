<h1><picture><source media="(prefers-color-scheme: dark)" srcset="design/logo/mark-dark.svg"><img src="design/logo/mark.svg" width="32" height="32" alt="" align="absmiddle"></picture> Bindcalm</h1>

A macOS app that collects keyboard shortcuts from every source it can reach — system symbolic hotkeys,
running apps' menus, Services, custom App Shortcuts, third-party preference files and config files
(Karabiner-Elements, skhd, Hammerspoon, BetterTouchTool, Keyboard Maestro, Alfred, Raycast), Carbon
hotkey probing and live key capture — groups them by physical key combination and highlights real conflicts.

- Swift 6 toolchain, SwiftUI, Apple frameworks only (no third-party dependencies).
- macOS 14+, Apple Silicon. Built and verified on macOS 27.0.1 with Xcode 27.0 / Swift 6.4.
- **The UI is in English.** Code, comments and docs are in English.
- Implementation plan and milestones: [PLAN.md](PLAN.md).

## Build and run

```sh
swift build                  # debug build
swift build -c release       # release build
swift test                   # unit tests (parsers, grouping, conflict rules, layout analysis)
scripts/bundle.sh            # → dist/Bindcalm.app (Info.plist + codesign)
open dist/Bindcalm.app
```

`scripts/bundle.sh` signs ad-hoc unless `BINDCALM_CODESIGN_IDENTITY` names a codesign identity
(for example `Developer ID Application: Name (TEAMID)`). A named identity is signed with a secure
timestamp, so Accessibility and Input Monitoring grants survive rebuilds. An unset, empty, or `-`
value keeps the ad-hoc signature (`codesign --sign - --timestamp=none`).

Headless modes (useful for scripting and for verifying the scanners without the GUI):

```sh
.build/debug/Bindcalm --dump               # JSON report on stdout
.build/debug/Bindcalm --dump --summary     # short human-readable summary
.build/debug/Bindcalm --dump --methods symbolicHotKeys,accessibilityMenus
.build/debug/Bindcalm --dump --all-methods # includes strategies that are off by default
.build/debug/Bindcalm --probe-symbols      # which private symbols resolve via dlsym
```

When run from a terminal, TCC attributes the process to the terminal app, so the CLI inherits the
terminal's Accessibility / Input Monitoring grants. The bundled app has its own identity and starts
without any grants.

## Permissions

- **Accessibility** (menus, global NSEvent monitor): checked with `AXIsProcessTrusted()`; the system
  prompt appears only when the user presses "Request".
- **Input Monitoring** (CGEvent tap): `CGPreflightListenEventAccess()`; `CGRequestListenEventAccess()`
  only on request.
- Both statuses are polled every 2 s (TCC does not notify apps) and shown at the bottom of the sidebar
  with buttons that open the right System Settings pane.
- By default the bundle is ad-hoc signed: TCC keys grants to the code hash, so every rebuild looks
  like a new app and grants may need to be re-approved. Set `BINDCALM_CODESIGN_IDENTITY` when
  running `scripts/bundle.sh` to sign with a Developer ID (or another stable identity) instead.
- The app is not sandboxed (it must read other apps' preferences and walk their menus).

## Documentation

- [How it works](docs/how-it-works.md): how shortcuts are grouped and what counts as a conflict.
- [Detection methods](docs/detection-methods.md): each scanner and its limitations.
- [Research](docs/research.md): other macOS methods, worked examples, and sources (checked 2026-10-04).

## Project files

`AGENTS.md` (agent rules), `PLAN.md` (plan, active tasks and milestones), `todo.md`, `done.md`,
`roadmap.md`, `ideas.md`, `toolchain.md`.

## License

You can use this project under **any** of the following licenses, at your choice:

1. [GNU GPLv3](LICENSE): free for open source applications on any platform, including embedded systems.
2. [Commercial license](PRICING.md): for proprietary applications, including embedded systems.

<!-- license-sync:start -->
Commercial use not covered by the GPLv3 requires a separate paid
license — see [PRICING.md](PRICING.md).
<!-- license-sync:end -->
