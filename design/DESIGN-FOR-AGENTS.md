# ShortcutClash: design spec for implementers and agents (v3, minimal glass)

Source of truth: tokens.json / tokens.css, the Figma v3 sections (see README.md) and the PNGs in screens/. Do not implement from the v1 or v2 sections. Do not change `Sources/ShortcutClashCore`. All UI strings are English.

## 0. Principle: minimal effects
Keep every effect at the lowest noticeable level. Translucency only on the sidebar and toolbar (88-92% opaque, 10 px blur). Everything else solid. One soft shadow per element. A 1 px highlight on buttons. No blobs, shards, glows, thick edges or springs. If an effect is hard to notice, that is correct. If it draws attention, reduce it.

## 1. Layout (window 1232x752, shown on a 1280x800 canvas with 24 px margin)
- **Sidebar** (translucent): x0, width 400, full height. Traffic lights at x16/36/56, y20 (12 px). Search input x16 y48, 368x36. Row at y100: "Conflicts only" label x16 with a 36x22 switch 10 px after it; counter right-aligned to x384 ("128 combos · 5 conflicts" in danger, or "· 0 conflicts" in ok). Selects at y134, 32 px high, 176 wide at x16 and x208 ("All methods", "All apps"). Section header y186 ("CONFLICTS · 5" in danger, "SHORTCUTS · 128" in muted when empty). Rows from y208, x16, 368x68, pitch 72. "OTHER SHORTCUTS · 123 ›" at y502. Footer at y616, 136 high: divider, "Detection methods" nav row (y10, 36 high, right text "7 of 9 · configure ›"), permission lines at y58 and y84 (6 px status dot, label, status in ok or warn) and a small "Request" button (26 high) at x284 y78.
- **Detail pane** (solid): x400, width 832. Toolbar on top, 52 high, translucent, 1 px bottom divider; buttons 32 high, right inset 16, gap 8: Rescan (primary), Live capture, Export JSON.
  - Header: combo title (34/42) at x32 y76 with a "Conflict" badge 16 px to its right, vertically centered on the title; explanation y128 (14/21, muted, width 740); "Detected by:" y176 with method badges; "Key code: 49 · modifiers: ⌘" y204.
  - Owner cards: x32, 768x152, pitch 168, first at y244. Icon tile 32 at (18,18); name x62 y16; id y36; path y52 (mono); action y78; badges y100; source y126 (mono).
- **Row** (368x68): combo x14 vertically centered (17/21 semibold); owners x112 y11; badges x112 y36 (gap 4, height 19); count bead 24 px at x330 y22, or a "layout" badge right-aligned at x354 and centered vertically.

## 2. Surfaces and effects
| Surface | Value |
|---|---|
| Window | radius 14, 1 px border, shadow 0/6/24, base `bg` plus the faint `tint` gradient (left to 60%) |
| Sidebar | `sidebar` fill (88% dark / 90% light), background blur 10, 1 px `hairline` right edge |
| Toolbar | `toolbar` fill (90% / 92%), blur 10, shadow 0/1/4, 1 px `hairline` bottom edge; the detail pane has a 0 to 8% accent gradient in its top 190 px so the translucency is just visible |
| Detail pane, cards | solid `surface` / `card`, cards radius 12, 1 px `border`, shadow 0/2/8 `shadowSoft` |
In SwiftUI use `NSVisualEffectView` (`.sidebar` / `.headerView` material) or `.regularMaterial` for the bars only; everything else is a plain color.

## 3. Components and states
| Component | Spec |
|---|---|
| Button (secondary) | 32 high (26 small), radius 8, label 13/16 medium centered, horizontal padding 15, `control` fill, 1 px `border`, inner top highlight 0/1/0 `highlight`, shadow 0/1/2 `shadow` |
| Button (primary) | same geometry, vertical gradient `primaryTop` to `primaryBottom`, label `onAccent`, inner highlight `primaryHighlight` |
| Hover | lift 1 px, fill `controlHover`, shadow 0/3/8, 120 ms ease-out |
| Pressed | no lift, fill `controlActive`, inner shadow 0/1/3 `inset`, 60 ms; release 160 ms |
| Focus | 2 px `focusRing` outline with a 2 px gap |
| Disabled / error | 45% opacity / danger border and text (primary error: `dangerFill` fill, `onDanger` text) |
| Input | 36 high, radius 8, `input` fill, 1 px `border`, inner shadow 0/1/2 `inset`; icon 14 px and text centered vertically, left padding 12, gap 8 |
| Input hover / focus / typing / error | `borderStrong` + `controlHover` fill / 1.5 px `accent` border + 3 px 28% accent ring (120 ms) / same, 2 px caret / `danger` border + 3 px 30% ring |
| Select | 32 high, radius 8, button styling, label left, 12 px chevron right, both centered vertically |
| Switch | 36x22, knob 18 centered vertically (2 px inset), `accent` when on, `trackOff` when off, 160 ms |
| Row | see layout; hover `controlHover` + shadow 0/2/6; selected `selected` fill + 40% accent 1 px border; focus 1.5 px accent border; disabled 50%; error owners in `danger` |
| Badge | pill, 19 high, 8 px horizontal padding, 11/14 medium, tone fill 14% + 1 px tone border 32%, text full tone. plist/prefs/AX/HIToolbox accent; reliable ok; partial and layout warn; heuristic, global muted; failed, Conflict danger |
| Count bead | 24 circle `dangerFill`, 12 semibold digit `onDanger`, centered both axes |

## 4. EmptyState (shared pattern)
Vertical stack, center-aligned, gap 12: orb 72 (tone fill 12%, 1 px tone border) with a 32 px vector icon, title 18/24 semibold, body 13/18 muted max 300 wide, actions 32 px buttons gap 10. Center the stack in its container (detail pane below the toolbar, or a tile).

| Variant | Icon / tone | Title | Actions |
|---|---|---|---|
| no-conflicts | check / ok | No conflicts found | Show all shortcuts |
| no-results | magnifier / accent | Nothing found | Clear search |
| nothing-selected | cursor / accent | Select a shortcut | none |
| live-waiting | record / accent | Waiting for key presses… | Stop |
| live-off | record / muted | Live capture is off | Start recording (primary) |
| scanning | 3/4 arc / accent | Scanning… | none |
| permission | lock / warn | Accessibility permission required | Request (primary), Open Settings |
| scan-failed | triangle / danger | Scan failed | Rescan (primary), Diagnostics |

Use it in the detail pane and in the list when it is empty. Copy that is derived, not literal app text: "Show all shortcuts", "Clear search", the Scan failed body and "Open Settings". Confirm against the app's real strings.

Sidebar rows also carry the weakest confidence of the group as a badge (reliable ok, partial warn, heuristic muted) after the method badges, and a conflict through layout shows a right-aligned warn badge "layout" instead of the count bead. Rows fit at most two method badges, then the confidence badge, then "+N".

## 4b. App screens beyond the main frame
Detection methods popover, Live capture sheet, Diagnostics sheet and the footer links are specified in APP-SCREENS.md. Footer: "Detection methods" nav row with "N of M · configure ›", permission rows, then a quiet "Diagnostics ›" link; no buttons or fills.

## 5. Themes
Implement the dark and light sets as dynamic colors in a `Theme.swift` resolved through the effective appearance. Follow the system, allow an override, cross-fade 200 ms. Replace hardcoded `.red/.blue/.green` with `danger`, `accent`, `ok`, `warn`. "All fine" uses `ok` (teal).

## 6. Reduce Transparency and Reduce Motion
- Reduce Transparency (`accessibilityReduceTransparency`): sidebar and toolbar use `opaque` (dark #161B24, light #F6F8FB), raised `opaqueRaised`, borders `opaqueBorder`; disable blur and the tint.
- Reduce Motion (`accessibilityReduceMotion`): no lift, no transitions, state changes are instant.
- Increase Contrast: use `borderStrong` for borders.

## 7. Accessibility and keyboard
Text tokens meet AA (see the table in STYLE-GUIDE.md). Tab order: search, Rescan, Live capture, Export JSON, filters, list, detail, footer. Arrow keys move through rows, Return selects, ⌘F focuses search, ⌘R rescans. Combos have spoken labels ("Command Space"). Minimum hit height 26 px.

## 8. Methods and settings
Detection settings are not on the main screen. The footer row "Detection methods · 7 of 9 · configure ›" opens the methods sheet/popover (`MethodsView`) with a switch per method. Permission rows are a quiet summary with one small action. The conflict list stays primary.

## 9. Centering rule
Anything that looks centered is centered on its bounding box on both axes via stack/auto-layout alignment, never magic offsets. Only the warning triangle icon gets a +1 px optical nudge. Verify with a screenshot of every screen.

## 10. Do / don't
- Do keep content solid and quiet, use tokens only, show tone color only in badges, counts and status text.
- Don't add blur to panels, cards or buttons, add glows, thick edges, backdrop blobs, stacked shadows, or use literal green for "ok".

## 11. SwiftUI mapping
`ContentView` (window, toolbar, split), `SidebarView` (bar material), `GroupRow`, `Badge` (Labels.swift), `DetailView`, `OwnerCard`, `MethodsView`, `PermissionBar`, `LiveCaptureView`. Add `Theme.swift`, a `SoftButtonStyle`, a `RecessedFieldStyle` and an `EmptyStateView`. `ShortcutClashCore` is unchanged.

## 12. Acceptance checklist
- [ ] Both themes match the PNGs, tokens only
- [ ] Only sidebar and toolbar are translucent (88-92%, blur 10); no other blur
- [ ] One soft shadow per element; no glow, blob or thick edge
- [ ] Buttons: 1 px highlight, 1 px hover lift, subtle press, focus ring
- [ ] All eight empty states exist, centered on one vertical axis
- [ ] All text AA on every surface; Reduce Transparency and Reduce Motion work
- [ ] Centering verified on a screenshot of every screen (bounding-box centers within 0.6 px)
- [ ] All UI strings English
- [ ] `Sources/ShortcutClashCore` untouched
