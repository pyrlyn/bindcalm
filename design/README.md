# ShortcutClash design package (v3, minimal glass)

English-only design handoff for the ShortcutClash macOS app. v3 returns to the original v1 layout and look and adds only a very small amount of translucency, depth and glass-button polish. It replaces the heavier v2 package.

| File | What it is |
|---|---|
| [STYLE-GUIDE.md](STYLE-GUIDE.md) | Principles, color, type, spacing, depth, motion, states, themes, accessibility, contrast table |
| [DESIGN-FOR-AGENTS.md](DESIGN-FOR-AGENTS.md) | Exact layout and values for implementers and coding agents, checklist, SwiftUI mapping |
| [tokens.json](tokens.json) | Tokens for light and dark, plus type, space, radius, blur, elevation, motion, sizes |
| [tokens.css](tokens.css) | The same tokens as CSS variables, with button, input, bar recipes and reduced-motion / reduced-transparency rules |
| [screens/](screens) | PNG exports of every Figma screen |

## Screens

| PNG | Content |
|---|---|
| screens/main-dark.png, screens/main-light.png | Main screen, conflict list first (1280x800) |
| screens/no-conflicts-dark.png, screens/no-conflicts-light.png | Main screen with no conflicts (EmptyState) |
| screens/empty-states-dark.png, screens/empty-states-light.png | All seven EmptyState variants and the pattern note |
| screens/components-dark.png, screens/components-light.png | Buttons, input, switch, row, badges, bead, selects with all states |

## Figma

File key `0ReL88zpUMqzQBGEklkq9v` (https://www.figma.com/design/0ReL88zpUMqzQBGEklkq9v).

- Screens page, section "ShortcutClash v3 - minimal glass - English - light + dark" (`89:33759`): main dark `89:33760`, main light `89:33893`, no-conflicts dark `89:34026`, light `89:34116`, empty states dark `89:34206`, light `89:34284`.
- Components page, section "ShortcutClash v3 - minimal glass components - states - light + dark" (`89:34417`): dark `89:34418`, light `89:34635`.
- Older sections are kept and labelled "v1 (superseded)" and "v2 (superseded)". Implement from v3 only.

## Scope

One main screen (conflict list first, detail on the right) plus its empty states. Hotkey-method settings are not a separate screen; see DESIGN-FOR-AGENTS.md, "Methods and settings". This package does not change app code (`Sources/`). Figma uses Inter as a stand-in for SF Pro.
