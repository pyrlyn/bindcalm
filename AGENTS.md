# Agent instructions

If an `AGENTS.md` or `CLAUDE.md` exists higher in the directory tree, follow it too; on conflict, ask
the creator.

## Project

Bindcalm — macOS app that detects keyboard shortcut conflicts. Swift package:
`BindcalmCore` (logic), `Bindcalm` (SwiftUI app + CLI), `BindcalmCoreTests`.

## Rules

- Language: code, comments, docs and commit messages in English. **Only UI strings are Russian.**
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
