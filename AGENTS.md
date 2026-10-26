# Agent instructions

If an `AGENTS.md` or `CLAUDE.md` exists higher in the directory tree, follow it too; on conflict, ask
the creator.

## Project

Bindcalm — macOS app that detects keyboard shortcut conflicts. Swift package:
`BindcalmCore` (logic), `Bindcalm` (SwiftUI app + CLI), `BindcalmCoreTests`.

## Rules

- Language: code, comments, docs and commit messages in English. **The UI is in English too** (design v3). Visuals come from `Theme.swift` and the components in `Components.swift`: no colour literals in views.
- Apple frameworks only; no third-party dependencies.
- Every detection method is its own `HotKeyDiscoveryStrategy` in
  `Sources/BindcalmCore/Strategies/`, registered in `StrategyRegistry.all`, independent of other
  strategies. Cross-method reasoning belongs in `ConflictAnalyzer` / `LayoutAnalyzer`.
- Strategies must fail soft: throw `DiscoveryError.permissionRequired` / `.unavailable`, never crash
  the scan. Private symbols are resolved with `dlsym` only; never call private setters.
- Never trigger TCC prompts implicitly — only from an explicit user action.
- Text Input Sources (TIS) calls run on the main actor only.
- Live capture must never record plain typing (only ⌘/⌃/⌥ combos and F-keys).
- Keep pure logic testable and covered by `swift test`.

## Verify

```sh
swift build && swift build -c release && swift test
scripts/bundle.sh && open dist/Bindcalm.app
.build/debug/Bindcalm --dump --summary
```

## Files

`PLAN.md` (active tasks + implementation plan), `todo.md`, `done.md`, `roadmap.md`, `ideas.md`,
`toolchain.md`, `README.md`.

UI design: see `design/DESIGN-FOR-AGENTS.md` (glass style, tokens, states, themes).

## Releasing

Releases go through pyrlyn/ci `release-apple-desktop.yml`, called by `.github/workflows/release.yml`
(dispatch-only, `version` input, `dry-run` first). The app is built from `xcode/project.yml`
(XcodeGen; `Bindcalm.xcodeproj` is generated, not committed) and every release is a prerelease
(Release configuration, Developer ID signed and notarised). Org secrets, by name: `MACOS_CERTIFICATE`,
`MACOS_CERTIFICATE_PWD`, `APPSTORE_CONNECT_KEY` (.p8), `APPSTORE_CONNECT_KEY_ID`,
`APPSTORE_CONNECT_ISSUER_ID`. Day-to-day builds stay on SwiftPM (`scripts/bundle.sh`).
