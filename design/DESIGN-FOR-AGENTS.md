# DESIGN-FOR-AGENTS: ShortcutClash main window

Self-contained spec for building the redesigned main window. Read this plus `tokens.json`; the PNGs in
`screens/` are the visual target. Figma: <https://www.figma.com/design/0ReL88zpUMqzQBGEklkq9v>
(Screens: nodes `74:33760` main dark, `74:33885` main light, `74:34010` empty dark, `74:34090` empty light;
Components: `76:33815` dark, `76:33975` light).

Status: design only. Do not change detection logic, strategies or the CLI. Only UI strings are Russian;
code, comments and commits are English (see `AGENTS.md`). Apple frameworks only, macOS 14+.

## 1. What the screen is

The window opens on the **conflict list**. The user's job is: see what clashes, who owns each side, how
sure we are, and fix it elsewhere. Settings for detection methods exist but are secondary.

Hierarchy (top = loudest):
1. Conflict rows (red count badge, red section header, selected row highlighted).
2. Detail of the selected combination (owners, methods, confidence, scope, source).
3. Filters and counters.
4. Quiet: "Остальные сочетания" (collapsed), "Методы обнаружения" nav row, permission bar.

## 2. Layout (px, window 1232 × 752 inside a 1280 × 800 canvas, 24 px margin)

```
Window  1232×752  radius 16  glassSurface  blur 40  shadow e4  inner highlight
├─ Sidebar  x0 w400 h752  glassStrong
│   ├─ traffic lights  x16 y18 (12 px, 8 px gap)
│   ├─ Search input    x16 y48 w368 h36  radius 10  glassInput
│   ├─ Filter row      y100:  [switch "Только конфликты"] ........ [counter "128 сочетаний · 5 конфликтов"]
│   ├─ Selects         y134 h32:  [Все методы x16 w176] [Все приложения x208 w176]
│   ├─ Section header  y186  "КОНФЛИКТЫ · 5"  (badge style 11/14, +6% tracking, danger)
│   ├─ Conflict rows   y208, h68 each, gap 4, x16 w368  (sort: real conflicts first)
│   ├─ Section header  "ОСТАЛЬНЫЕ СОЧЕТАНИЯ · 123  ›"  (muted, collapsed by default)
│   └─ Footer (quiet)  y616 h136, hairline on top
│       ├─ Nav row "Методы обнаружения      7 из 9 · настроить ›"  x16 y10 w368 h36, muted
│       └─ Permission bar: "Универсальный доступ есть" / "Мониторинг ввода нет [Запросить]"  12 px
└─ Detail  x400 w832  (content inset 32 → x432)
    ├─ Toolbar  y10 h32, right-aligned, 8 px gap, right inset 16: [Пересканировать primary] [Живой захват] [Экспорт JSON]
    ├─ Header   y76  combo 34/40 bold rounded + badge "Конфликт"
    ├─ Explanation y128  14/20 muted, w740 (the existing status text from DetailView.explanation)
    ├─ Methods line y176 "Обнаружено методами:" + method badges;  key code line y204 mono 12
    └─ Owner cards y244, w768 h152, gap 16 (one per owner)
        icon tile 32 (x18 y18), name 15 semibold (x62 y16), bundle id mono 11, path 11,
        action 13 medium (y78), badges row (y100: method, confidence, scope), source mono 11 (y126)
```

Snap to the 4/8 grid when building: row inset 14 → 16, row height 68 → 72.

Row anatomy (368 wide): combo (17/22 semibold rounded, x16) · owners (13 medium, x112, max 2 lines) ·
under it a badge row (methods in `accent`, then **confidence** badge) · right: conflict count circle 24 px
`danger` fill, or the `раскладка` `warn` badge for a layout conflict. Status order in the list:
`conflict` → `layoutConflict` → `inAppDuplicate` → none.

Empty state (no conflicts): sidebar counter turns `ok` ("0 конфликтов"); the list shows the normal
sections; detail shows a centered 112 px `ok` orb (glass fill `ok` 14%, 2 px `ok` 60% border, 70 px
blurred `ok` glow at 30%), a 44 px check stroke (6 px, round caps, `ok`), title "Конфликтов не найдено"
(22/28 semibold), subtitle "Все 128 сочетаний просканированы, пересечений нет." (14 muted) and a
secondary button "Показать все сочетания".

Hotkey/method settings: stay in the existing popover (`MethodsView`) opened from the quiet "Методы
обнаружения" nav row (and the existing toolbar item). There is no separate settings screen in this design.
The popover should use the same glass (`glassSurface`, radius 16, blur 28, `e3`) and the same Switch and
row components. It relates to the main screen only through the method counter in the footer and the
"Все методы" filter.

## 3. Glass recipe (per layer)

Each glass layer = backdrop blur + tint fill + 1 px border + inner top highlight + drop shadow.

| Layer | Fill token | Blur | Border | Inner highlight | Shadow |
|---|---|---|---|---|---|
| Window | `glassSurface` | 40 | `glassBorder` | `0 1 0 glassHighlight` | `0 24 64 glassShadow` |
| Sidebar | `glassStrong` | (inherits window) | none, `hairline` right edge | none | none |
| Card | `glassSurface` | 28 | `glassBorder` | yes | `0 6 20` |
| Input / secondary button / select | `glassInput` | 16–20 | `glassBorder` | yes | `0 2 8` |
| Selected row | `glassSelected` | 16 | `accent` @ 45% | yes | `0 4 12` |
| Conflict row (not selected) | `glassSurface` @ 50% | none | `hairline` | none | none |
| Primary button | `accent` solid | none | none | `0 1 0` white 35% | `0 4 12 accent@35%` |

SwiftUI mapping: `.ultraThinMaterial` ≈ `glassSurface`, `.thinMaterial` ≈ `glassStrong`; add a
tint overlay with the token color and a `strokeBorder` overlay. The window uses
`NSVisualEffectView` (`.sidebar` / `.hudWindow`) behind SwiftUI content if materials are too flat.
Ambient backdrop: two blurred ellipses (see STYLE-GUIDE section 3), drawn behind the window content only
when transparency is allowed.

## 3b. Alignment and optical centering

Same rule as STYLE-GUIDE.md. In SwiftUI:

- Labels and icons inside buttons, badges, pills and circles are centered on both axes: build them as
  stacks with `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)` or `HStack(alignment: .center)` and equal padding (buttons 0/14, badges
  3/8). Never position a label with hand-set x/y offsets. Fixed-size containers (count circle, clear
  button, switch knob) center their child by `(container - child) / 2` on each axis.
- Fields, selects, nav rows and switches: leading icon, text, chevron and clear button share the
  vertical center of the control. The switch knob is centered in its track, and switch, label and counter
  share one center line in the filter row.
- Toolbar items, traffic lights and the section's title share one horizontal center line; toolbar buttons
  are 32 px high and centered in the 52 px toolbar band.
- Row content: the key combination is vertically centered in the row; the owners and badge block is
  centered as a group; the count circle and the `раскладка` badge are centered on the row's center line.
- Badges next to large text (the `Конфликт` badge beside the 34 px combo) are centered on the text box's
  vertical center, not on its top.
- Empty state: orb, glow, check mark, title, subtitle and button sit on one vertical axis, the center of the
  detail pane (x = 816 in the 1280 canvas). The check mark's bounding box is centered in the orb.
- Optical centering: glyph boxes include side bearings and line gaps, so after centering by box, check
  the render. Arrows, chevrons and the `⌕` / `×` glyphs may be nudged by at most 1 px; triangular or
  asymmetric icons are centered on their visual mass, not their bounding box. Prefer real vector icons
  (SF Symbols with `.imageScale`) over text glyphs in the implementation.
- Verify on a render, not on the structure: measure label and container centers (tolerance 0.5 px) and
  look at the exported PNGs at 2×.

Measured in the Figma file (all four screens and both component sheets): label-to-container center offset 0 px for buttons, badges and count circles; empty-state elements 0 px off the axis; filter row label, switch and counter share one center.

## 4. Tokens

Use `tokens.json` (both themes) or `tokens.css`. In SwiftUI create `Theme.swift` with a `Theme` enum of
dynamic colors (`Color(nsColor: NSColor(name: nil) { appearance in ... })`) named exactly like the
tokens (`bg`, `fg`, `muted`, `accent`, `danger`, `ok`, `warn`, `glassSurface`, ...), plus constants for
spacing, radii, blur and motion. Never hardcode a hex in a view.

## 5. Type

See STYLE-GUIDE section 4. Combos use `.system(size:, weight:, design: .rounded)`; badge section headers
are uppercase with `tracking(0.06 × size)`; mono for bundle IDs, key code and sources.

## 6. Component states

Durations and easing come from `tokens.json` `motion`.

**Button primary**

| State | Fill | Shadow | Highlight | Transform |
|---|---|---|---|---|
| default | `accent` | `0 4 12 accent@35%` | white 35% | none |
| hover (140 ms ease-out) | accent +10% white | `0 6 18 accent@45%` | white 55% | y −1 |
| pressed (80 ms ease-in) | accent −12% black | `0 1 4 accent@30%` | black 25% at `0 2 0` | scale 0.97 |
| release (280 ms spring, damping 0.7) | back to default | | | |
| focus | default + 2 px `focusRing` outside | | | |
| disabled | 40% opacity | none | none | none |

**Button secondary (glass)**

| State | Fill | Shadow | Transform |
|---|---|---|---|
| default | `glassInput` | `0 2 8` | none |
| hover | `glassInputHover`, highlight 50% | `0 5 14` | y −1 |
| pressed | `glassInput`, inner dark top shadow | `0 0 2` | scale 0.97 |
| focus | + 2 px `focusRing` | | |
| disabled | 40% opacity | none | none |

**Input (search)**

| State | Fill | Border | Extra |
|---|---|---|---|
| default | `glassInput`, blur 20 | `glassBorder` | placeholder `muted` |
| hover | `glassInputHover` | `glassBorder` | highlight 50% |
| focus (160 ms ease-out) | `glassInputHover`, blur 28 | `accent` 60% | 3 px ring `accent` 25% |
| typing | as focus | as focus | caret `accent`; top highlight tinted `accent`; clear `×` fades in 120 ms |
| disabled | 50% opacity | | |
| error | `glassInput` | `danger` | 3 px ring `danger` 25%; message 11 px `danger` below at +6 px |

Input focus and typing effect: on focus, fill, border, ring and blur animate together over 160 ms; the
ring is drawn outside the field. While text is non-empty show the clear button. Focus must be visible
without color (the ring adds shape).

**Switch:** 40×24, knob 20 with a small shadow; on = `accent` track, off = `fg` 18%; knob moves with a
180 ms spring; hover +10% brightness; focus ring; disabled 40%.

**Row:** default (conflict rows have `glassSurface` 50% + `hairline`), hover (120–140 ms, fill 90%,
`glassBorder`, shadow `0 4 12`), selected (`glassSelected` + `accent` 45% border), focus (2 px ring),
disabled = method turned off (70% opacity plus a `выключено` `muted` badge).

**Badge:** pill, `3 / 8` padding, 11/14 semibold, fill token @16%, text token. Mapping: conflict `danger`;
reliable `ok`; partial `warn`; heuristic `muted`; method and scope `accent`; layout conflict `warn`.

**Select:** same glass as secondary button, 32 px high, chevron `muted`.

## 7. Theme switching

- Follows the system by default; manual override system / light / dark persisted in `@AppStorage`.
- Resolve the theme before the first frame (set the appearance before showing the window) so there is no
  flash of the wrong theme.
- Animate colors only, 240 ms ease-out; never animate layout or blur radius; skip on first launch.
- Reduce motion: switch instantly. Reduce transparency: opaque fallback per theme (section 8).
- Light glass is more opaque than dark glass (64/80/55% vs 8/12/7% white). Do not share values.

## 8. Fallbacks

**Reduced motion** (`@Environment(\.accessibilityReduceMotion)`): no lift, no scale, no springs; hover and
focus state changes are instant (or an 80 ms opacity fade); no theme crossfade.

**Reduced transparency** (`@Environment(\.accessibilityReduceTransparency)`, macOS Reduce Transparency):
replace every glass layer with an opaque fill, no blur, no ambient blobs, shadow `e1` only, keep borders:
- dark: window/panels `#161B24`, raised `#1E2430`, border `#323A49`
- light: window/panels `#F6F8FB`, raised `#FFFFFF`, border `#C9D2DF`

Selected row = raised fill + `accent` border. All text tokens still pass AA (higher than on glass).

**Increased contrast:** `glassBorder` to 40% (dark), `hairline` ×2.

## 9. Accessibility

- Contrast: all text tokens ≥ 4.67:1 on glass in both themes (table in STYLE-GUIDE section 9). Do not
  put text on glass with a token that is not in that table.
- Focus ring visible on every interactive element; hit targets ≥ 28 px; keyboard reachable.
- Meaning is never color-only (count badge, section header, text confidence).
- VoiceOver label for a row: combo, owners, status, confidence, methods (use Russian strings).

## 10. Keyboard

- `⌘F` focuses the search input; `Esc` clears it, a second `Esc` blurs it.
- `↑ / ↓` moves the row selection in the list; `Return` focuses the detail; `Tab` order: search → switch
  → selects → list → footer (methods, permissions) → toolbar → detail.
- `⌘R` = "Пересканировать". `Space` toggles a focused switch. `Esc` closes the methods popover.
- Keep existing shortcuts untouched (this app finds conflicts; do not introduce new global ones).

## 11. Mapping to the current SwiftUI code (for the later migration)

| Design | Current code | Change |
|---|---|---|
| Window, split layout | `ContentView` (`NavigationSplitView`, `.searchable` in sidebar) | Keep the structure. Add backdrop and glass window styling. |
| Sidebar | `SidebarView` (filters, `List`, `PermissionBar`) | Split `List` into two sections from `model.filteredGroups` by `group.status`: conflicts first, then others (collapsed). Presentation only, plus a partitioned computed property. |
| Conflict count in header | `model.conflictCount`, `model.groups.count` | Already there. Use `ok` when 0. |
| Row | `GroupRow`, `Badge` (`Labels.swift`) | Add a confidence badge (weakest `Confidence` among the group's findings). Restyle. |
| Detail header | `DetailView.header`, `explanation` | Restyle only. |
| Owner cards | `OwnerCard` (`GroupBox`) | Replace `GroupBox` with the glass card. |
| Empty state | `ContentUnavailableView`, "Ничего не найдено" in `SidebarView.overlay` | Add the `ok` orb variant for zero conflicts. |
| Methods (secondary) | `MethodsView` popover, toolbar "Методы" | Add the quiet footer nav row opening the same popover. |
| Permission bar | `PermissionBar` | Move into the quiet footer style. |
| Colors | `.red`, `.blue`, `.green`, `.orange`, `.purple`, `.teal` literals in views and `Labels.swift` | Replace with `Theme` tokens. Scope/method colors currently use purple/teal/blue; the design uses `accent` for both. |
| Theme override | none | New `@AppStorage` setting (system/light/dark) applied before the window shows. A UI control for it is not designed here. |

Do not touch `ShortcutClashCore`.

## 12. Do / Don't

Do:
- Use tokens only. Keep the conflict list the first thing the user sees.
- Keep glass layers few: window, sidebar, cards, inputs. Blur them over the backdrop, with a border and highlight.
- Keep motion at the values above, and test with Reduce Motion and Reduce Transparency on.
- Keep Russian UI strings; code and docs in English.

Don't:
- No purple or purple gradients; no literal green for "fine" (use `ok`).
- No stacking more than two blurred layers on top of each other.
- No lift above 1 px, no scale below 0.97, no animation longer than 280 ms.
- No new features: do not invent screens, filters or data.
- Do not put method toggles in the primary view; they stay quiet.
- Do not use raw hex or `.red`/`.green` literals in views.

## 13. Acceptance checklist

- [ ] App opens on the conflict list; real conflicts are on top; counter reads `N сочетаний · M конфликтов`.
- [ ] Rows show combo, owners, method badges, confidence badge, and conflict count or `раскладка`.
- [ ] Detail shows owners, methods, confidence, scope and source for the selected combination.
- [ ] Methods settings are reachable from a quiet footer row and the toolbar; no separate settings screen.
- [ ] Light and dark both match `screens/*.png` within normal rendering differences.
- [ ] Theme follows the system, can be overridden, has no flash on launch, and transitions in 240 ms.
- [ ] Translucent search input with focus, typing and error states as in section 6.
- [ ] Buttons have hover and press states with the specified durations and easing.
- [ ] Reduce Motion: no lift/scale/spring. Reduce Transparency: opaque fallback in both themes.
- [ ] All text tokens pass AA (measured on the built UI for both themes and both fallbacks).
- [ ] Focus ring visible; everything reachable by keyboard; hit targets ≥ 28 px.
- [ ] Empty state uses the `ok` glow (teal), not green.
- [ ] Centering: button and badge labels, count circles, switch knobs, field icons and toolbar items are centered on both axes (≤ 0.5 px off on a render); empty-state illustration, text and button share one axis; optical centering of icons checked at 2×.
- [ ] No hardcoded hex or system-color literals left in views; no change to `ShortcutClashCore`.
- [ ] `swift build && swift test` pass; before/after screenshots attached to the PR.
