# App screens beyond the v3 Figma frames

The v3 Figma file has frames for the main screen, the detail pane, six empty states and the component sheet
(see `design/` on PR #1). The app has more views than that. They were designed together with the SwiftUI
implementation from the same tokens (`Theme.swift` mirrors `design/tokens.json`) and are documented here so
`design/` stays the source of truth. Figma frames for them are still to be added (see the PR description).

## Layout (all screens)

- Sidebar 400 px, full window height, translucent (blur under an 88-90% fill). Traffic lights float over its top strip.
- Toolbar 52 px, only above the detail pane, translucent (92% fill): Appearance menu, Rescan (primary), Live capture, Export JSON.
- Detail pane solid. Rows 68 px (72 px pitch). Cards radius 12, controls radius 8, rows radius 10.
- Reduce Transparency: bars become opaque tokens. Reduce Motion: no hover lift, no switch or spinner animation.

## Detection methods popover (520 x 600)

Header 52 px: title 15/semibold left, small Rescan right. One row per method, split by 1 px hairlines: name 13/medium
plus permission/live badges, 12 muted summary, status line (dot, state, count, duration) tinted by state, soft switch
(36 x 22) on the right. Below a stronger divider: layout-analysis switch with explanation, and the "Show duplicates
inside one app" switch. Opens from the quiet footer link "Detection methods".

## Live capture sheet (640 x 520)

Header 56 px: title 18/semibold, Clear, Start recording (primary) or Stop (primary danger), Close. Body: 13 muted
explanation, two soft switches (CGEvent tap, NSEvent monitors), two status badges, optional warning line. Then the log
(rows split by hairlines: combo, time, tap/global/local flags, verdict, frontmost app, registry owners) or an EmptyState:

| State | Icon / tone | Title | Actions |
| --- | --- | --- | --- |
| Off (new, 8th empty state) | record / muted | Live capture is off | Start recording (primary) |
| Waiting | record / accent | Waiting for key presses | Stop recording |

## Diagnostics sheet (640 x 560)

Header like capture (Close only). Four cards (`SectionCaps` title, 16 px padding): Permissions, Keyboard layouts,
Private and undocumented symbols (dlsym), Method results. Opened from the footer link or Shift-Cmd-D.

## Footer

Row 1: "Detection methods >" (quiet link) and "N of M · Diagnostics >". Hairline. Then permission rows (dot, name,
Granted/Needed, small Request and Settings buttons only when missing; 26 px high).

## Empty states (shared `EmptyStateView`)

No conflicts, No matching shortcuts, Select a shortcut, Scanning, Permission needed, Scan failed, Live capture is off,
Waiting for key presses. Orb 72, title 18/24 semibold, body 13 muted (max 300), 32 px actions, gap 12, one vertical
axis, centered in its area (sidebar list, detail pane or capture log).

## Preview mode

`SHORTCUTCLASH_PREVIEW=<scenario>` shows fixtures; `-appearanceMode light|dark` forces the theme. Scenarios: main,
nothing-selected, no-conflicts, no-results, scanning, permission, scan-failed, methods, capture-off, capture-waiting,
capture-log, diagnostics.
