# ShortcutClash: design spec for implementers and agents (v2, 3D glass)

Source of truth: tokens.json / tokens.css, Figma (see README.md), and the PNGs in screens/. Do not implement from the v1 sections in Figma. Do not change `Sources/ShortcutClashCore`. All UI strings are English.

## 1. Layout (canvas 1440x900)
- **Top bar slab**: x32 y24, 1376x64, radius 22, depth 6. Search input 440x40 centered vertically (face y12). Right-aligned keycaps, height 40, depth 5, right inset 24, gap 10: Rescan (primary), Live capture, Export JSON (glass).
- **Sidebar slab**: x32 y116, 420x764, radius 28, depth 8.
  - Filters: switch 48x28 at (24,20), label at x84, counter right-aligned at x396; selects h36: 176 wide at x24 and 180 wide at x216, y68.
  - List: "CONFLICTS · N" header (danger) y124; rows from y148, height 76, pitch 84, x20 width 380: keycap combo left, owners at x140, method and confidence badges, count bead or "layout" badge right. A collapsed "OTHER SHORTCUTS · N" row follows.
  - Quiet footer: divider y632; "Methods · 7 of 9 enabled" row y642 h40; permission rows (Accessibility, Input Monitoring + Request keycap h28) at y690 and y722.
- **Detail slab**: x476 y116, 932x764, radius 28, depth 8.
  - Header: large keycaps (h76) at (36,32); Conflict badge; explanation y134 width 840, 14/20.
  - "Detected by:" y182; "Key code: 49 · modifiers: ⌘" y212.
  - Owner cards: height 176, depth 5; first at (36,252) width 860; further cards stack with a (20,200) offset and 36 px narrower for parallax. Card: icon tile 44 radius 13 at (24,24); name x84 y20; id y43; path y60; action y88; badges y116; source y146.

## 2. Glass values
Slab: fill `glassFill` + sheen gradient, backdrop blur 36 (sidebar 40, bar 30), border 1.5 px gradient (`glassBorderTop` to `glassBorderBottom`), inner shadows 0/2/0 highlight, 0/-3/6 dark, 0/0/10 rim, outer shadows 0/10/20 `shadowNear` and 0/36/64 `shadowFar`, thickness wall `glassEdge` at depth px below. In SwiftUI approximate with `.ultraThinMaterial` or `NSVisualEffectView` (`.hudWindow`/`.underWindowBackground`) plus the tint, gradient stroke and shadow stack.
Backdrop: `bg` plus four blobs `blob1..4`, blur 110, opacity 0.8, plus three rotated glass shards.

## 3. Components and states
| Component | Spec |
|---|---|
| Keycap (glass) | h40 (h28 compact), radius 14, wall 5 (3 compact), gradient `keycapTop` to `keycapBottom`, blur 18, label callout 13/18 medium centered on the face |
| Keycap (primary) | same, gradient `keycapPrimaryTop` to `keycapPrimaryBottom`, wall `keycapPrimaryWall`, label `onAccent` |
| Hover | lift 2 px (wall shows 7), glow 22 px `glow`, +12% white, 140 ms ease-out |
| Pressed | face sinks to wall-1, shadow 0/1/3, inner top shadow 0/3/5 black 35%, 80 ms ease-in, release spring 280 ms (response 0.28, damping 0.7) |
| Focus | 2 px `focusRing`, offset 4 px, 120 ms |
| Disabled / error | 40% opacity / `dangerFill` keycap with `onDanger` text |
| Input | recessed glass `glassInput`, h40 radius 12, inner shadow 0/3/5 dark + 0/-1/0 white 45%, blur 20, leading icon and text centered on the vertical axis |
| Input focus / typing | border `accent` 90%, glow 18 px `accent`, blur 20 to 30, caret 2 px, 160 ms ease-out |
| Input error | border `danger`, glow 14 px |
| Select | h36 radius 14, recessed glass, chevron vector centered |
| Switch | 48x28 glass track, 22 px bead, 180 ms spring (damping 0.8), on = accent fill |
| Row | h76 radius 18; hover lift 2 px + fill 10-55%; selected `selected` tint + 90% accent border; focus ring; disabled 55%; error owners in `danger` |
| Badge | pill, fill token 18%, 1 px border token 45%, text full token (AA checked); confidence: reliable=ok, partial=warn, heuristic=muted, failed=danger; method badges accent |
| Count bead | 26-28 px, `dangerFill`, digit `onDanger` centered on both axes |
| Combo keys | each key a keycap; large (h76) in detail header, small (h30) in rows |

## 4. Input effects
Focus and typing: border brightens to accent 90%, an 18 px accent glow fades in over 160 ms, backdrop blur 20 to 30, placeholder dims, caret 2 px accent. Search placeholder "Search: ⌘⇧K, app, action". Error shows danger border and the leading icon and text keep the same vertical center.

## 5. EmptyState
Vertical stack, center-aligned, gap 16: orb 96 (glass, tone glow, vector icon), title 20/24 semibold, body 13/18 muted max 300, actions 40 px keycaps gap 12. Variants and tone: No conflicts found (ok), Nothing found (accent) with Clear search, Select a shortcut (accent), Waiting for key presses… (accent) with Stop, Scanning… (accent), Accessibility permission required (warn) with Request and Settings, Scan failed (danger) with Rescan and Diagnostics. Use it in the detail pane and in the list when it is empty. Copy marked as derived in the style guide must be confirmed against real app strings.

## 6. Themes
Dark and light token sets must both be implemented as dynamic colors (a `Theme.swift` with `Color(light:dark:)` resolving through `NSAppearance`). Follow the system; allow override. Switching cross-fades 240 ms. No hardcoded `.red/.blue/.green`; map conflict to `danger`/`dangerFill`, "all fine" to `ok`, partial/layout/missing to `warn`.

## 7. Reduced motion and transparency
- Reduce Motion (`accessibilityReduceMotion`): no lift, sink, spring, glow pulse or crossfade; state changes instant or an 80 ms opacity change.
- Reduce Transparency (`accessibilityReduceTransparency`): fills `opaque`, `opaqueRaised`, `opaqueBorder` (dark #121A2B/#1A2438/#364560; light #F4F7FC/#FFFFFF/#C4CFE0), no blur, no blobs or shards, keep wall and shadows.
- Increase Contrast: use the opaque set and a 2 px border.

## 8. Accessibility and keyboard
Text tokens meet AA (min 4.91:1 on worst-case glass; see STYLE-GUIDE.md). Tab order: search, Rescan, Live capture, Export, filters, list, detail. Arrow keys move through rows, Return selects, ⌘F focuses search, ⌘R rescans. Every keycap has an accessibility label (the combo spoken as "Command Space"). Minimum hit area 28 px.

## 9. Methods and settings
Hotkey detection settings are not on the main screen. The footer row "Methods · 7 of 9 enabled" opens a popover/sheet (`MethodsView`) listing the methods with switches; permission rows open the system panes. The main screen only shows the summary and permission state; the conflict list stays primary.

## 10. Centering rule
Everything that appears centered is centered on its bounding box on both axes (no shadows, glows or walls counted), through stack/auto-layout alignment, never magic offsets. Only unevenly weighted vector icons get an optical nudge of at most 2 px (warning triangle +2, cursor and lock -1). Keycap labels center on the face. Verify with a screenshot of every screen.

## 11. Do / don't
- Do use the tokens, keep slabs thick with edge and shadow, show combos as keycaps, keep copy in English.
- Don't use literal green for "ok", flat opaque panels (except under Reduce Transparency), text below AA, mixed radii in one component, or hand-tuned offsets for centering.

## 12. SwiftUI mapping
`ContentView` (backdrop + top bar slab + two slabs), `SidebarView`, `GroupRow` (row + keycap combo), `Badge` in Labels.swift, `DetailView`, `OwnerCard`, `MethodsView`, `PermissionBar`, `LiveCaptureView`. Add `Theme.swift` (colors), `GlassSlab`, `KeycapButtonStyle`, `GlassFieldStyle` and `EmptyStateView`. `ShortcutClashCore` is unchanged.

## 13. Acceptance checklist
- [ ] Both themes match the PNGs; tokens only, no hardcoded colors
- [ ] Slabs have edge, rim, blur and shadow stack; keycaps have wall, hover, press, focus
- [ ] Input focus, typing and error effects present
- [ ] All seven empty states exist and are centered on one vertical axis
- [ ] All text AA on glass and on opaque fallback
- [ ] Reduce Motion and Reduce Transparency fallbacks work
- [ ] Centering verified on a screenshot of every screen (bbox centers within 0.6 px, optical nudges documented)
- [ ] All UI strings English
- [ ] `Sources/ShortcutClashCore` untouched
