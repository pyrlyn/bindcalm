# Bindcalm style guide (v3, minimal glass)

## 1. Principle: minimal effects
The design is the original v1 layout: a window with a quiet sidebar and a detail pane. Effects are present but kept at the lowest level that is still noticeable. Content always comes first.

- **Transparency**: only the sidebar and the toolbar are translucent, 88-92% opaque, with a 10 px blur. Detail pane, cards, rows, inputs and buttons are solid.
- **Backdrop**: one faint accent tint at the left edge of the window. No blobs, no shards, no glow.
- **Depth**: one gentle shadow layer per element (window 0/6/24, card 0/2/8, button 0/1/2). No stacked slabs, no side walls.
- **Glass buttons**: soft keycap feel from a 1 px inner highlight on the top edge, a 1 px border and a small shadow. Hover lifts 1 px. Press removes the lift and shows a small inner shadow.
- **Quiet content**: tone colors appear only in badges, counts and status text, never as large fills.

## 2. Color
Semantic tokens (full list with glass values in tokens.json):

| Token | Dark | Light | Use |
|---|---|---|---|
| bg | #0F1319 | #E8EDF4 | window backdrop |
| surface | #161B23 | #FFFFFF | detail pane (solid) |
| fg | #F2F4F8 | #0E1522 | primary text |
| muted | #A3ACBB | #4B5870 | secondary text |
| accent | #7DA8FF | #1F4FD1 | interaction, focus, method badges |
| danger | #FF7A75 | #B3261E | conflict text (bead fill: #FF7A75 / #C7352B) |
| ok | #5CD9E0 | #0A6670 | no conflict, reliable, granted (teal, never literal green) |
| warn | #F2B84B | #7D5200 | partial, layout, missing permission |
| sidebar | rgba(22,27,35,.88) | rgba(246,248,252,.90) | translucent sidebar |
| toolbar | rgba(22,27,35,.90) | rgba(250,251,253,.92) | translucent toolbar |
| control | #212733 | #FAFBFD | button, select fill |

## 3. Type
System font (SF Pro in the app). Combo title 34/42 semibold, row combo 17/21 semibold, empty title 18/24 semibold, card name 15/18 semibold, row owner 14/18 medium, body 14/21, label 13/16, caption 12/15, badge 11/14 medium, section caps 11/14 semibold with 6% tracking, mono 11/15.

## 4. Spacing, radii, blur
- Spacing follows a 4/8 grid: 4, 8, 12, 16, 24, 32, 40, 48, 64. A few positions inherited from v1 (for example 14, 18, 36 px insets inside rows and cards) are kept on purpose to preserve the v1 layout.
- Radii: badge pill, button/input/select 8, row 10, card 12, window 14, orb 36.
- Blur: 10 px on sidebar and toolbar only.

## 5. Motion
Hover 120 ms ease-out `cubic-bezier(0.2,0,0,1)`, press 60 ms `cubic-bezier(0.4,0,1,1)`, release 160 ms, input focus 120 ms, switch 160 ms, focus ring 100 ms, theme change 200 ms. Reduced motion: no lift and no transitions.

## 6. States
Every control has default, hover, focus, active, disabled and error (Components screens).
- **Button**: hover lift 1 px + shadow 0/3/8 + lighter fill; focus 2 px accent ring with a 2 px gap; active no lift and inner shadow 0/1/3; disabled 45%; error danger border and text (primary error uses the danger fill).
- **Input**: hover stronger border; focus and typing 1.5 px accent border with a 3 px 28% ring and a 2 px caret; error danger border with a 3 px 30% ring; disabled 50%.
- **Row**: hover raised fill and 0/2/6 shadow; selected accent 9-14% fill with a 40% accent border; focus 1.5 px accent border; disabled 50%; error owner text in danger.
- **Switch**: 36x22 track, 18 px knob, accent when on.

## 7. Themes
Follow the system appearance with an optional manual override (system, light, dark). Cross-fade tokens over 200 ms (instant under Reduce Motion). Layout and geometry are identical in both themes.

## 8. EmptyState pattern
One shared pattern, one vertical axis, gap 12: orb 72 (flat tone fill 12% and 1 px tone border) with a vector icon, title 18/24 semibold, body 13/18 muted (max 300), actions as 32 px buttons with gap 10. Variants: no conflicts (ok), nothing found, nothing selected, live capture waiting, scanning, permission needed (warn), scan failed (danger). Copy marked derived in DESIGN-FOR-AGENTS.md should be checked against the app's real strings.

## 9. Centering rule
Anything that looks centered is centered on its geometric bounding box on both axes, using stack/auto-layout alignment, never manual offsets. Button labels, badge text, count digits, orb icons, input icon and text, select label and chevron, switch knob, row combos and EmptyState content are all measured. The only optical nudge is +1 px on the warning triangle in its orb. Verified in Figma on the final build: 392 checks, bounding-box centers within 0.6 px, no failures.

## 10. Accessibility
- Text tokens meet WCAG AA (4.5:1) on every surface they appear on, including the worst-case sidebar (full tint under the 88-90% fill) and on 14% tone badge fills.
- Reduce Transparency: sidebar and toolbar become solid (dark #161B24 / raised #1E2430 / border #323A49; light #F6F8FB / #FFFFFF / #C9D2DF). Nothing else changes.
- Reduce Motion: no lift, no transitions.
- Color is never the only signal: conflicts also carry a "Conflict" badge and a count. Focus is always visible. Minimum hit height 26 px.

### Contrast (computed)
| Theme | Token | Worst contrast (any surface or badge) | Pass AA 4.5 |
|---|---|---|---|
| dark | fg | 11.2 | yes |
| dark | muted | 5.36 | yes |
| dark | accent | 5.24 | yes |
| dark | danger | 4.87 | yes |
| dark | ok | 6.89 | yes |
| dark | warn | 6.63 | yes |
| dark | onAccent | 7.9 | yes |
| dark | onDanger | 7.3 | yes |
| light | fg | 14.38 | yes |
| light | muted | 5.28 | yes |
| light | accent | 4.94 | yes |
| light | danger | 4.69 | yes |
| light | ok | 4.89 | yes |
| light | warn | 5.01 | yes |
| light | onAccent | 6.05 | yes |
| light | onDanger | 5.29 | yes |
