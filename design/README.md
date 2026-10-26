# Bindcalm design package (v3, minimal glass)

English-only design handoff for the Bindcalm macOS app. v3 returns to the original v1 layout and look and adds only a very small amount of translucency, depth and glass-button polish. It replaces the heavier v2 package.

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
| screens/empty-states-dark.png, screens/empty-states-light.png | All eight EmptyState variants and the pattern note |
| screens/components-dark.png, screens/components-light.png | Buttons, input, switch, row, badges, bead, selects with all states |
| screens/methods-dark.png, screens/methods-light.png | Detection methods popover (520x600) |
| screens/capture-off-*.png, capture-waiting-*.png, capture-log-*.png (dark and light) | Live capture sheet states (640x520) |
| screens/empty-live-off-dark.png, screens/empty-live-off-light.png | Eighth EmptyState: "Live capture is off" |
| screens/diagnostics-dark.png, screens/diagnostics-light.png | Diagnostics sheet (640x560) |
| screens/footer-dark.png, screens/footer-light.png | Sidebar footer: methods link, permission rows, Diagnostics link |
| [APP-SCREENS.md](APP-SCREENS.md) | The app screens that go beyond the main screen, with exact values |

## Figma

File key `0ReL88zpUMqzQBGEklkq9v` (https://www.figma.com/design/0ReL88zpUMqzQBGEklkq9v).

- Screens page, section "Bindcalm v3 - minimal glass - English - light + dark" (`89:33759`): main dark `89:33760`, main light `89:33893`, no-conflicts dark `89:34026`, light `89:34116`, empty states dark `89:34206`, light `89:34284`.
- Screens page, same section, added with the app screens: Detection methods popover dark `94:33771` / light `94:33819`; Live capture dark `93:33759` / light `93:33881` (sheets off `93:33761` / `93:33883`, waiting `93:33794` / `93:33916`, log `93:33825` / `93:33947`); Diagnostics dark `95:33759` / light `95:33819`; Sidebar footer dark `94:33867` / light `94:33905`; Empty state "live capture is off" dark `95:33804` / light `95:33864`. The main frames' footers also carry the "Diagnostics ›" link.
- Components page, section "Bindcalm v3 - minimal glass components - states - light + dark" (`89:34417`): dark `89:34418`, light `89:34635`.
- Older sections are kept and labelled "v1 (superseded)" and "v2 (superseded)". Implement from v3 only.

## Scope

One main screen (conflict list first, detail on the right), its empty states, the Detection methods popover, the Live capture and Diagnostics sheets and the footer links (see APP-SCREENS.md). The design is implemented in `Sources/Bindcalm` (Theme.swift, Components.swift); `Sources/BindcalmCore` is untouched by the design. The docs are English only; there are no ru/uk copies. Figma uses Inter as a stand-in for SF Pro.
