# ShortcutClash style guide (v2, 3D glass)

## 1. Concept
Thick pieces of frosted glass float over a vivid, blurred color field. Three big slabs (top bar, conflict list, detail) have real thickness: a visible side edge, a bright top rim and a deep shadow. Buttons are glass **keycaps** you can press, and every key combination in the app is drawn as keycaps too, so the UI looks like what it manages: keyboard shortcuts.

## 2. 3D construction
- **Slab**: edge frame offset by depth (5-8 px) filled with `glassEdge`; face with `glassFill` plus a top-to-bottom sheen, backdrop blur 36-40, a 1.5 px gradient border (bright top, dim bottom), inner shadows (top highlight 0/2, bottom dark 0/-3/6, rim 0/0/10), a soft specular glare, and shadows near 0/10/20 and far 0/36/64.
- **Keycap**: wall (5 px, `keycapWall`) under a face with a vertical gradient, a refraction edge (1.5 px stroke white 95% to 25% to clear), an inner highlight 0/1.5 white 85%, an inner base shade and backdrop blur 18. The primary keycap uses the `keycapPrimary*` blue gradient.
- **Depth cues**: stacked owner cards are offset to show parallax; backdrop contains rotated glass shards behind the slabs for refraction.
- **Backdrop**: base color plus four blurred blobs (cyan, blue, coral, amber; blur 110, opacity 0.8).

## 3. Color
Semantic tokens, both themes (full list in tokens.json):

| Token | Dark | Light | Use |
|---|---|---|---|
| bg | #060914 | #EAF1FA | backdrop base |
| fg | #F5F8FC | #0B1220 | primary text |
| muted | #C6CFDD | #41506A | secondary text |
| accent | #B8D2FF | #1B47C7 | interaction, focus, method badges |
| danger | #FFBDB6 | #B3261E | conflict text (fills: #FF7A6E / #C7352B) |
| ok | #78EEF0 | #0A6670 | no conflict, reliable, granted (aqua, never literal green) |
| warn | #FFD27A | #7D5200 | partial, layout, missing permission |

Glass fills: dark rgba(8,13,26,.50) / .62 raised / .44 input; light rgba(255,255,255,.66) / .78 / .58.

## 4. Type
System font (SF Pro in the app). Title 20/24 semibold, headline 16/22 semibold, body 14/20, callout 13/18 medium, caption 12/16, badge 11/14 semibold, large keycap 32/40, mono 11/16.

## 5. Spacing, radii, blur
- Spacing on a 4/8 grid: 4, 8, 12, 16, 24, 32, 40, 48, 64.
- Radii: badge pill, keycap 10-14, input 12-14, row 18, card 20, bar 22, slab 26-28, orb 48.
- Blur: keycap 18, input 20 (30 on focus), bar 30, slab 36-40.

## 6. Motion
Hover 140 ms ease-out `cubic-bezier(0.2,0,0,1)`; press 80 ms ease-in `cubic-bezier(0.4,0,1,1)`; release spring 280 ms (response 0.28, damping 0.7); input focus 160 ms; switch 180 ms spring (damping 0.8); focus ring 120 ms; theme change 240 ms crossfade. Reduced motion: no lift/sink/spring; state changes become instant or an 80 ms opacity change.

## 7. States
- **Keycap**: default; hover lifts 2 px with a 22 px accent glow and +12% white; active sinks to wall depth minus 1 with shadow 0/1/3 and an inner top shadow; focus is a 2 px ring at a 4 px offset; disabled 40% opacity; error uses `dangerFill`.
- **Input** (recessed glass): default; hover raises fill; focus accent border 90%, 18 px glow, blur 20 to 30; typing keeps focus look plus a 2 px caret; error danger border and 14 px glow; disabled 40%.
- **Switch**: glass track, 22 px glass-bead knob, 180 ms spring.
- **Row**: hover lifts 2 px; selected uses `selected` tint and a 90% accent border; focus ring outside; disabled 55%; error shows owner text in danger.

## 8. Theme switching
Follow the system appearance by default, with an optional manual override (light / dark / system). Cross-fade tokens over 240 ms (instant under Reduce Motion). Both themes share layout and geometry; only token values change.

## 9. EmptyState pattern
One vertical axis, gap 16: 96 px glass orb with a tone glow and a vector icon, 20/24 semibold title, 13/18 muted body (max 300 px), 40 px keycap actions with gap 12. Variants: no conflicts (ok), nothing found, select a shortcut, waiting for key presses, scanning, permission required (warn), scan failed (danger). Where copy is derived rather than literal app text (Show all shortcuts, Clear search, Scan failed body), the app should confirm wording.

## 10. Centering rule
Anything that looks centered must be centered on its **geometric bounding box on both axes**, measured without shadows, glows or walls. Use auto-layout/stack centering, never manual offsets. Only vector icons with uneven visual mass get an optical nudge of at most 2 px (warning triangle +2, cursor and lock -1), and the nudge is documented. Keycap labels are centered on the face, not on face plus wall. Verified in Figma by comparing absolute bounding-box centers (424 checks, tolerance 0.6 px; the only deviation is the intentional triangle nudge).

## 11. Accessibility
- Text tokens meet WCAG AA 4.5:1 against the worst-case glass over the backdrop (blob at 0.8 over base, glass tint, sheen), and much higher on opaque fallbacks.
- Reduce Transparency: replace glass with opaque fills (dark #121A2B / raised #1A2438 / border #364560; light #F4F7FC / #FFFFFF / #C4CFE0), no blur, no blobs.
- Reduce Motion: see section 6. Never rely on color alone: conflicts also carry a "Conflict" badge and a count.
- Everything is keyboard reachable with a visible focus ring; minimum 28 px hit area.

### Contrast table (computed)
| Theme | Pair | Value | Worst case on glass | On opaque fallback |
|---|---|---|---|---|
| dark | fg | `#F5F8FC` | 7.34 | 16.32 |
| dark | muted | `#C6CFDD` | 4.97 | 11.06 |
| dark | accent | `#B8D2FF` | 5.1 | 11.34 |
| dark | danger | `#FFBDB6` | 4.91 | 10.93 |
| dark | ok | `#78EEF0` | 5.69 | 12.65 |
| dark | warn | `#FFD27A` | 5.49 | 12.21 |
| light | fg | `#0B1220` | 9 | 17.44 |
| light | muted | `#41506A` | 6.33 | 7.58 |
| light | accent | `#1B47C7` | 5.89 | 7.05 |
| light | danger | `#B3261E` | 5.09 | 6.09 |
| light | ok | `#0A6670` | 5.19 | 6.21 |
| light | warn | `#7D5200` | 5.31 | 6.35 |
| dark | primary keycap text | `#07122B on #C4D8FF→#7DA6FF` | 7.76 | - |
| light | primary keycap text | `#FFFFFF on #3563E0→#1F4FD1` | 5.23 | - |
| dark | count bead digit | `#2A0806 on #FF7A6E` | 7.27 | - |
| light | count bead digit | `#FFFFFF on #C7352B` | 5.29 | - |
