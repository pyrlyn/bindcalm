# ShortcutClash style guide

## 1. Style in one paragraph

ShortcutClash is a tooling app, so the glass is there to give depth and hierarchy, not decoration.
The window is a frosted pane over a soft, dim backdrop. Sidebar, cards and inputs are translucent glass
layers with a 1 px border and a thin top highlight, like light catching a bevel. Depth comes from blur,
a soft two-part shadow and that highlight, never from heavy gradients. Color is restrained: neutral
surfaces, one blue accent, a coral `danger` for conflicts, and a teal `ok` for "all clear". No purple, no
green. Typography is the system font (SF Pro) with rounded digits and key symbols for key combinations.

Principles:

1. **Conflicts first.** The app opens on the conflict list. Real conflicts sit on top and are the only
   loud elements. Everything else is quiet.
2. **Glass has levels.** `surface` (panels, window), `strong` (sidebar, raised), `input` (fields and
   secondary buttons). More opaque means closer to the user.
3. **One accent.** Blue is interaction and method identity. Red means conflict. Teal means fine.
   Amber means partial or needs attention.
4. **Motion is small.** 1 px lift, 0.97 press scale, 80–180 ms. Anything bigger is a bug.
5. **Always legible.** Every text token passes WCAG AA on the glass in both themes (section 9), and there
   is an opaque fallback.

## 2. Color tokens (semantic)

Never use raw hex in views. Use the token. Values below are `light` / `dark`; the full list (including
ambient and opaque fallbacks) is in `tokens.json`.

| Token | Light | Dark | Use |
|---|---|---|---|
| `bg` | `#E8EDF4` | `#0A0D12` | Backdrop base (behind the window) |
| `fg` | `#0E1522` | `#F2F4F8` | Primary text |
| `muted` | `#4B5870` | `#A3ACBB` | Secondary text, icons, captions |
| `accent` | `#1F4FD1` | `#7DA8FF` | Primary button, method badges, focus, selection border |
| `onAccent` | `#FFFFFF` | `#06122B` | Text on accent fill |
| `danger` | `#B3261E` | `#FF7A75` | Conflict: count badge, "Конфликт", counter text |
| `ok` | `#0B6F79` | `#5CD9E0` | No conflict, reliable confidence, empty-state glow |
| `warn` | `#8A5A00` | `#F2B84B` | Partial confidence, layout conflict, missing permission |
| `glassSurface` | `rgba(255,255,255,.64)` | `rgba(255,255,255,.08)` | Window, cards |
| `glassStrong` | `rgba(255,255,255,.80)` | `rgba(255,255,255,.12)` | Sidebar |
| `glassInput` | `rgba(255,255,255,.55)` | `rgba(255,255,255,.07)` | Inputs, secondary buttons, selects |
| `glassInputHover` | `rgba(255,255,255,.85)` | `rgba(255,255,255,.12)` | Hover/focus fill of inputs and secondary buttons |
| `glassSelected` | `rgba(31,79,209,.10)` | `rgba(125,168,255,.16)` | Selected row |
| `glassBorder` | `rgba(255,255,255,.85)` | `rgba(255,255,255,.14)` | 1 px glass border |
| `hairline` | `rgba(14,21,34,.08)` | `rgba(255,255,255,.07)` | Dividers |
| `glassHighlight` | `#FFFFFF` | `rgba(255,255,255,.30)` | Inner top edge `0 1 0` |
| `glassShadow` | `rgba(30,45,80,.16)` | `rgba(0,0,0,.50)` | Drop shadow |
| `focusRing` | `rgba(31,79,209,.55)` | `rgba(125,168,255,.70)` | 2 px focus ring |

The glass tint is deliberately different per theme. Light glass uses a much higher white tint (64–80%)
because a low tint over a light backdrop loses text contrast. Dark glass needs only 7–12% white.

`ok` is a teal, on purpose: "all clear" should feel calm and should not be mistaken for a generic
success-green. It is used for the empty-state glow, the `надёжно` badge, the `0 конфликтов` counter and
granted permissions.

Confidence mapping: `надёжно` → `ok`, `частично` → `warn`, `эвристика` → `muted`. Scope and method
badges use `accent`. Conflict status → `danger`; layout conflict → `warn`.

## 3. Backdrop

Flat `bg` plus two blurred ellipses (140 px blur): `ambientAccent` (top left, 55% × 70% of the screen)
and `ambientOk` (bottom right, 50% × 60%). Opacity: light 35% / 35%, dark 16% / 12%. They are what the
glass blurs, so the blur reads as depth. Keep them subtle; they are lowered in dark mode so text on glass
stays AA.

## 4. Type scale

System font. Use `.rounded` design for key combinations only.

| Token | Size / line | Weight | Use |
|---|---|---|---|
| `largeTitle` | 34 / 40 | Bold, rounded | Combo in the detail header |
| `title` | 22 / 28 | Semibold | Empty-state title |
| `combo` | 17 / 22 | Semibold, rounded | Combo in list rows |
| `headline` | 15 / 20 | Semibold | Owner name |
| `body` | 14 / 20 | Regular | Explanations |
| `callout` | 13 / 18 | Medium | Owners in rows, buttons, inputs |
| `caption` | 12 / 16 | Regular | Footer, counters, labels |
| `badge` | 11 / 14 | Semibold | Badges, section headers (uppercase, +6% tracking) |
| `mono` | 11 / 16 | Regular | Bundle IDs, key code, sources |

Figma uses Inter as a stand-in for SF Pro. In the app use the system font, not Inter.

## 5. Spacing, radii, blur, elevation

- **Spacing:** 4/8pt grid: `4, 8, 12, 16, 24, 32, 40, 48, 64`. Component insets are 12/16, gaps 4/8/12/16.
  Known deviation in the Figma mock: list rows use a 14 px inset and a 68 px height. Snap to 16 px and
  72 px when implementing.
- **Radii:** `xs 6`, `sm 8` (small buttons, icon tiles), `md 10` (inputs, buttons, selects), `lg 12`
  (rows), `xl 16` (cards, window), `pill 999` (badges, switch).
- **Blur (backdrop):** `sm 12` small buttons, `md 16` buttons/rows, `input 20` (28 when focused), `lg 28`
  cards, `window 40` window/sidebar.
- **Elevation** (all shadows use `glassShadow`, all glass also has the inner `0 1 0 glassHighlight`):

| Level | Offset Y | Blur | Use |
|---|---|---|---|
| `e1` | 2 | 8 | Inputs, secondary buttons at rest |
| `e2` | 4 | 12 | Selected row, primary button at rest (accent-tinted) |
| `e3` | 8 | 24 | Cards |
| `e4` | 24 | 64 | Window |

## 6. Motion

| Token | Value |
|---|---|
| `press` | 80 ms, ease-in `cubic-bezier(0.4, 0, 1, 1)` |
| `focus` | 120 ms, ease-out `cubic-bezier(0.2, 0, 0, 1)` |
| `hover` | 140 ms, ease-out `cubic-bezier(0.2, 0, 0, 1)` |
| `inputFocus` | 160 ms, ease-out |
| `switch` | 180 ms spring (damping 0.8) |
| `release` | 280 ms spring (response 0.28, damping 0.7) |
| `theme` | 240 ms, ease-out, colors only |

Button hover: lift −1 px, shadow grows (`0 6 18`), top highlight 30% → 55%, fill +10% white.
Button press: scale 0.97, shadow shrinks (`0 1 4`), inner top shadow goes dark, fill −12%; the release
springs back.
Input focus: fill `glassInput` → `glassInputHover`, border → `accent` at 60%, 3 px ring in `accent` at 25%,
backdrop blur 20 → 28 px. While typing, the top highlight tints toward `accent`, the caret is `accent`, and
a clear `×` fades in over 120 ms.

**Reduced motion** (`accessibilityReduceMotion`): no lift, no scale, no springs, no theme crossfade.
State changes are instant, or a 80 ms opacity fade at most. The ambient backdrop is static anyway.

## 7. Components and states

All components have `default / hover / focus / disabled`; buttons add `pressed`, inputs add `typing` and
`error`, rows add `selected`. The Figma "components" section shows each in both themes.

| Component | States | Notes |
|---|---|---|
| Button primary | default, hover, pressed, focus, disabled | Accent fill, accent-tinted shadow. Disabled = 40% opacity, no shadow. |
| Button secondary (glass) | default, hover, pressed, focus, disabled | `glassInput` fill, border, blur 16. |
| Input (search) | default, hover, focus, typing, disabled, error | Translucent glass. Error = `danger` border + ring + 11 px message. The error state is generic, the current app has no validated input. |
| Switch | off, on, hover, focus, disabled | Track `accent` when on. |
| List row | default, hover, selected, focus, disabled | Disabled = "method off" rows, 70% plus a `выключено` badge. |
| Badge | danger, warn, ok, accent, muted | 16% tint fill, full-token text. |
| Select | default, hover, focus, disabled | Same glass as secondary button. |
| Card (owner) | default | `glassSurface`, `xl` radius, `e3`. |

## 8. Themes: light, dark, switching

- **Follows the system by default.** Appearance is automatic unless the user overrides it.
- **Manual override** with three values: system (default), light, dark. Stored in `UserDefaults`/`@AppStorage`.
  On the web/CSS side the override is `data-theme="light|dark"` on the root; no attribute = follow
  `prefers-color-scheme`.
- **No flash.** The theme is resolved before the first frame. In SwiftUI/AppKit set the window appearance
  (`NSApp.appearance` or `.preferredColorScheme`) before the window is shown. On the web set `data-theme`
  from an inline script in `<head>`.
- **Transition:** 240 ms ease-out, animating colors only (backgrounds, text, borders), never layout and
  never blur radius. Not run on first launch. Disabled with reduce motion.
- **Per-theme glass** (do not reuse values across themes): light uses a 64/80/55% white tint and a white
  1 px border; dark uses 8/12/7% and a 14% white border. Shadows are soft blue-gray in light and black in dark.
- **Reduced transparency** (`accessibilityReduceTransparency`, macOS "Reduce transparency"): replace glass
  with the opaque fallback of the same theme: window/panel `opaque`, raised `opaqueRaised`, border
  `opaqueBorder` (dark `#161B24` / `#1E2430` / `#323A49`, light `#F6F8FB` / `#FFFFFF` / `#C9D2DF`), blur 0,
  no ambient blobs, shadow `e1` only. Contrast on the fallback is higher than on glass (table below).
- **Increased contrast** (`accessibilityContrast`): raise `glassBorder` to 40% in dark and use `hairline` at 2×.

### Alignment and optical centering

- Labels and icons inside buttons, badges, pills and circles are centered on both axes: build them as
  auto-layout with primary and counter axis alignment `center` and equal padding (buttons 0/14, badges
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

## 9. Accessibility

- **Contrast (WCAG AA, 4.5:1 text, 3:1 non-text).** Computed for text tokens over the glass surface and the
  strong glass at the plain backdrop and with the accent ambient blob, plus over the opaque fallback.
  Minimum across all combinations is 4.67:1, so everything passes AA in both themes.

| Theme | Pair | Value | Worst case on glass (4 backdrops) | On opaque fallback |
|---|---|---|---|---|
| light | fg | `#0E1522` | 15.93 | 17.18 |
| light | muted | `#4B5870` | 6.25 | 6.74 |
| light | accent | `#1F4FD1` | 5.91 | 6.37 |
| light | danger | `#B3261E` | 5.7 | 6.14 |
| light | ok | `#0B6F79` | 5.14 | 5.54 |
| light | warn | `#8A5A00` | 5.17 | 5.57 |
| light | onAccent on accent | `#FFFFFF / #1F4FD1` | 6.78 | - |
| light | onDanger on danger | `#FFFFFF / #B3261E` | 6.54 | - |
| light | accent (focus ring base) vs bg, non-text 3:1 | `#1F4FD1` | 5.76 | - |
| dark | fg | `#F2F4F8` | 10.73 | 15.68 |
| dark | muted | `#A3ACBB` | 5.16 | 7.54 |
| dark | accent | `#7DA8FF` | 5.02 | 7.33 |
| dark | danger | `#FF7A75` | 4.67 | 6.82 |
| dark | ok | `#5CD9E0` | 7.01 | 10.24 |
| dark | warn | `#F2B84B` | 6.6 | 9.65 |
| dark | onAccent on accent | `#06122B / #7DA8FF` | 7.9 | - |
| dark | onDanger on danger | `#2A0806 / #FF7A75` | 7.3 | - |
| dark | accent (focus ring base) vs bg, non-text 3:1 | `#7DA8FF` | 8.26 | - |

  Badge text sits on a 16% tint of its own color; the pair was not measured separately, it is slightly
  lower than the table values on glass. Re-check with a real build before release.
- **Focus:** every interactive element shows a 2 px `focusRing` outside the element (3 px 25% ring plus
  accent border for inputs). Never remove it; focus is not shown by color alone, the ring has its own shape.
- **Hit targets:** minimum 28 px, buttons and inputs are 32–36 px, list rows 68–72 px.
- **Meaning is not color-only:** conflict rows have the `N` count badge and the red `КОНФЛИКТЫ` header;
  confidence is text (`надёжно`, `частично`, `эвристика`), not only a color.
- **Keyboard:** see DESIGN-FOR-AGENTS.md section 10.
- **VoiceOver:** each row reads "combo, owners, status, confidence, methods".
