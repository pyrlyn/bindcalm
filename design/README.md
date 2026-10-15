# ShortcutClash design package (v2, 3D glass)

English-only design handoff for the ShortcutClash macOS app. It replaces the earlier v1 package.

| File | What it is |
|---|---|
| [STYLE-GUIDE.md](STYLE-GUIDE.md) | Human-readable style guide: concept, 3D construction, color, type, spacing, motion, states, accessibility, contrast table |
| [DESIGN-FOR-AGENTS.md](DESIGN-FOR-AGENTS.md) | Exact pixel and value spec for implementers and coding agents, with a checklist and SwiftUI mapping |
| [tokens.json](tokens.json) | Tokens for light and dark themes, plus type, space, radius, blur, depth, motion |
| [tokens.css](tokens.css) | Same tokens as CSS variables, with slab and keycap recipes and reduced-motion / reduced-transparency handling |
| [screens/](screens) | PNG exports of every Figma screen (below) |

## Screens

| PNG | Content |
|---|---|
| screens/main-dark.png, screens/main-light.png | Main screen with conflicts (1440x900) |
| screens/no-conflicts-dark.png, screens/no-conflicts-light.png | Main screen with no conflicts (EmptyState) |
| screens/empty-states-dark.png, screens/empty-states-light.png | All seven EmptyState variants plus the pattern note |
| screens/components-dark.png, screens/components-light.png | Components and states: keycaps, input, switch, row, badges, bead, selects |

## Figma

File: https://www.figma.com/design/0ReL88zpUMqzQBGEklkq9v/ShortcutClash (file key `0ReL88zpUMqzQBGEklkq9v`).

- Screens page, section "ShortcutClash v2 - 3D glass - English - light + dark": main dark `83:33760`, main light `83:33977`, no-conflicts dark `83:34194`, light `83:34350`, empty states dark `83:34510`, light `83:34640`.
- Components page, section "ShortcutClash v2 - 3D glass components - states - light + dark": dark `83:34828`, light `83:35150`.
- The older design is kept in sections labelled "v1 (superseded)". Do not implement from it.

## Scope

One main screen (conflict list first, detail on the right) plus its empty states. Hotkey-method settings are not a separate screen here; see DESIGN-FOR-AGENTS.md, section "Methods and settings". This package does not change app code (`Sources/`); implementation is a separate step. Figma uses Inter as a stand-in for SF Pro.
