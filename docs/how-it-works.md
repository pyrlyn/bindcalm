# How Bindcalm works

Every detection method is an independent strategy behind one protocol:

```swift
public protocol HotKeyDiscoveryStrategy: Sendable {
    var id: DiscoveryMethod { get }
    var displayName: String { get }          // English, shown in the UI
    var summary: String { get }
    var defaultEnabled: Bool { get }
    var requiredPermission: PermissionKind? { get }
    var isLiveCapture: Bool { get }
    func discover(in context: DiscoveryContext) async throws -> [DiscoveredHotKey]
}
```

Each `DiscoveredHotKey` records the combo (virtual key code + modifiers, shown as `⌘⇧K`), the owner
(name, bundle ID, path), the method, a confidence level (`reliable` / `partial` / `heuristic`), a scope,
the action (menu title, hotkey name, preference key) and the exact source. Strategies run concurrently;
one failing or lacking permission never stops the scan. Each strategy can be toggled in the UI (the
choice is persisted) and every shortcut shows which method(s) found it.

### Scope and what counts as a conflict

| Scope | Meaning |
| --- | --- |
| `global` | Fires regardless of the frontmost app (symbolic hotkeys, Carbon hotkeys, Services, Apple menu). |
| `inApp` | Menu key equivalent that fires only while its app is frontmost. |
| `observed` | A key press seen in live capture. Evidence only, never a party in a conflict. |

`ConflictAnalyzer` groups claims by combo and marks:

- **Conflict** (red badge with the number of owners): two different owners where at least one is
  global — global vs global, or global vs any in-app shortcut of another app.
- **In-app duplicate**: one app binds the combo to several of its own menu items (optional, grey).
- **Layout conflict** (globe icon): a character-defined menu shortcut lands on a globally owned key in
  another enabled ASCII-capable layout (see *Layout analysis*).
- The same combo used inside several apps' menus is **not** a conflict: only the frontmost app gets it.
- Owners found by several methods are merged (macOS from the plist and from SkyLight is one owner).
- The anonymous owner from the Carbon probe corroborates a known global owner instead of opposing it.
- Disabled claims (e.g. a switched-off symbolic hotkey) are shown greyed and ignored.
- For a conflict, the detail panel names the likely winner. Claims are ranked by where they hook
  the keyboard, earliest first: HID remapper (Karabiner) → event tap (skhd, BetterTouchTool) →
  symbolic hotkey → Carbon hotkey (Alfred, Raycast, Keyboard Maestro, Hammerspoon `hs.hotkey`,
  the Carbon probe) → frontmost menu (Accessibility menus, App Shortcuts, Services). Two owners
  on the same earliest layer are a tie. Live observations and disabled claims do not win.
  Preference heuristics do not name a layer, so they lose to every known hook.
