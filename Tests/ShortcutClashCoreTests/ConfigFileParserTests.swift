import XCTest
@testable import ShortcutClashCore

final class ConfigFileParserTests: XCTestCase {
    func testKarabinerSelectedProfileOnly() throws {
        let root = try json("""
        {
          "profiles": [
            {
              "name": "Default",
              "selected": true,
              "complex_modifications": {
                "rules": [
                  {
                    "description": "Open Terminal",
                    "manipulators": [
                      {
                        "type": "basic",
                        "from": {
                          "key_code": "t",
                          "modifiers": { "mandatory": ["left_command", "left_shift"], "optional": ["caps_lock"] }
                        }
                      },
                      { "type": "basic", "from": { "key_code": "a" } },
                      { "type": "mouse_basic", "from": { "key_code": "b", "modifiers": { "mandatory": ["command"] } } }
                    ]
                  }
                ]
              }
            },
            {
              "name": "Unused",
              "selected": false,
              "complex_modifications": {
                "rules": [
                  {
                    "description": "Ignored",
                    "manipulators": [
                      { "from": { "key_code": "b", "modifiers": { "mandatory": ["command"] } } }
                    ]
                  }
                ]
              }
            }
          ]
        }
        """)
        let parsed = KarabinerParser.parse(root)
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].combo, KeyCombo(keyCode: 17, modifiers: [.command, .shift]))
        XCTAssertEqual(parsed[0].action, "Open Terminal")
        XCTAssertEqual(parsed[0].scope, .global)
    }

    func testKarabinerUsesTheFirstProfileWhenNoneIsSelected() throws {
        let root = try json("""
        { "profiles": [ { "name": "Only", "complex_modifications": { "rules": [
          { "description": "F1", "manipulators": [ { "from": { "key_code": "f1", "modifiers": { "mandatory": ["fn"] } } } ] }
        ] } } ] }
        """)
        let parsed = KarabinerParser.parse(root)
        XCTAssertEqual(parsed.count, 1)
        // F-keys drop the implicit fn flag, same as every other claim in the app.
        XCTAssertEqual(parsed[0].combo, KeyCombo(keyCode: 122, modifiers: []))
    }

    func testSkhdConfig() {
        let text = """
        # comment
        cmd + shift - return : open -a Terminal
        hyper - a : echo hyper
        meh - space : echo meh
        .blacklist [
          "loginwindow"
        ]
        :: focus @
        focus < ctrl - 0x21 : echo p
        cmd - delete : echo del
        cmd - n [
          "terminal" : echo hi
        ]
        cmd - a -> : echo pass
        not a hotkey
        """
        let parsed = SkhdParser.parse(text)
        XCTAssertEqual(parsed.map(\.combo), [
            KeyCombo(keyCode: 36, modifiers: [.command, .shift]),
            KeyCombo(keyCode: 0, modifiers: .hyper),
            KeyCombo(keyCode: 49, modifiers: [.control, .option, .shift]),
            KeyCombo(keyCode: 33, modifiers: [.control]),
            KeyCombo(keyCode: 117, modifiers: [.command]),
            KeyCombo(keyCode: 45, modifiers: [.command]),
            KeyCombo(keyCode: 0, modifiers: [.command]),
        ])
        XCTAssertEqual(parsed[0].action, "open -a Terminal")
        XCTAssertEqual(parsed[3].action, "echo p")
        XCTAssertEqual(parsed[5].action, "по приложению")
        XCTAssertTrue(parsed[6].action.contains("пропускает клавишу"))
        XCTAssertFalse(parsed.contains { $0.action.contains("loginwindow") })
    }

    func testHammerspoonLiteralBindsIgnoreComments() {
        let source = """
        -- hs.hotkey.bind({"cmd"}, "x", function() end)
        --[[
        hs.hotkey.bind({"cmd"}, "z", function() end)
        ]]
        hs.hotkey.bind({"cmd", "alt"}, "T", function() end)
        hs.hotkey.bind(
          {"ctrl", "shift"},
          "space",
          "Launch terminal",
          function() end)
        hs.hotkey.new({'fn'}, 'f1', function() end)
        local mods = {"cmd"}
        hs.hotkey.bind(mods, "a", function() end)
        """
        let parsed = HammerspoonParser.parse(source)
        XCTAssertEqual(parsed.map(\.combo), [
            KeyCombo(keyCode: 17, modifiers: [.command, .option]),
            KeyCombo(keyCode: 49, modifiers: [.control, .shift]),
            KeyCombo(keyCode: 122, modifiers: []),
        ])
        XCTAssertEqual(parsed[1].action, "Launch terminal")
        XCTAssertEqual(parsed[0].action, "Сочетание Hammerspoon")
    }

    func testBetterTouchToolPreset() throws {
        let root = try json("""
        {
          "BTTPresetName": "Main",
          "BTTPresetContent": [
            {
              "BTTAppBundleIdentifier": "BT.G",
              "BTTAppName": "Global",
              "BTTTriggers": [
                {
                  "BTTTriggerClass": "BTTTriggerTypeKeyboardShortcut",
                  "BTTShortcutKeyCode": 49,
                  "BTTShortcutModifierKeys": 1048576,
                  "BTTPredefinedActionName": "Show BTT",
                  "BTTEnabled": 1,
                  "BTTEnabled2": 1
                },
                {
                  "BTTTriggerClass": "BTTTriggerTypeKeyboardShortcut",
                  "BTTShortcutKeyCode": -1,
                  "BTTAdditionalActions": [
                    {
                      "BTTTriggerClass": "BTTTriggerTypeKeyboardShortcut",
                      "BTTShortcutKeyCode": 8,
                      "BTTShortcutModifierKeys": 655360,
                      "BTTGestureNotes": "toggle",
                      "BTTEnabled2": 0
                    }
                  ]
                },
                {
                  "BTTTriggerClass": "BTTTriggerTypeNormalMouse",
                  "BTTShortcutKeyCode": 0,
                  "BTTShortcutModifierKeys": 1048576
                }
              ]
            },
            {
              "BTTAppBundleIdentifier": "com.apple.Safari",
              "BTTAppName": "Safari",
              "BTTTriggers": [
                {
                  "BTTTriggerClass": "BTTTriggerTypeKeyboardShortcut",
                  "BTTShortcutKeyCode": 15,
                  "BTTShortcutModifierKeys": 262144,
                  "BTTTriggerTypeDescription": "Reload"
                }
              ]
            }
          ]
        }
        """)
        let parsed = BetterTouchToolParser.parse(root)
        XCTAssertEqual(parsed.count, 3)
        XCTAssertEqual(parsed[0].combo, KeyCombo(keyCode: 49, modifiers: [.command]))
        XCTAssertEqual(parsed[0].scope, .global)
        XCTAssertTrue(parsed[0].enabled)
        XCTAssertEqual(parsed[0].action, "Show BTT")
        XCTAssertEqual(parsed[1].combo, KeyCombo(keyCode: 8, modifiers: [.option, .shift]))
        XCTAssertFalse(parsed[1].enabled)
        XCTAssertEqual(parsed[1].action, "toggle")
        XCTAssertEqual(parsed[2].combo, KeyCombo(keyCode: 15, modifiers: [.control]))
        XCTAssertEqual(parsed[2].scope, .inApp)
        XCTAssertEqual(parsed[2].action, "Reload")
    }

    func testKeyboardMaestroPlist() throws {
        let root = try plist("""
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
          <key>MacroGroups</key>
          <array>
            <dict>
              <key>Name</key><string>Global</string>
              <key>Activate</key><string>Normal</string>
              <key>Macros</key>
              <array><dict>
                <key>Name</key><string>Open</string>
                <key>Triggers</key>
                <array><dict>
                  <key>MacroTriggerType</key><string>HotKey</string>
                  <key>KeyCode</key><integer>40</integer>
                  <key>Modifiers</key><integer>768</integer>
                </dict></array>
              </dict></array>
            </dict>
            <dict>
              <key>Name</key><string>Off</string>
              <key>Activate</key><string>Deactivated</string>
              <key>Macros</key>
              <array><dict>
                <key>Name</key><string>Nope</string>
                <key>Triggers</key>
                <array><dict>
                  <key>MacroTriggerType</key><string>HotKey</string>
                  <key>KeyCode</key><integer>0</integer>
                  <key>Modifiers</key><integer>256</integer>
                </dict></array>
              </dict></array>
            </dict>
            <dict>
              <key>Name</key><string>Safari only</string>
              <key>Targeting</key><string>Included</string>
              <key>Macros</key>
              <array><dict>
                <key>Name</key><string>Find</string>
                <key>Triggers</key>
                <array>
                  <dict>
                    <key>MacroTriggerType</key><string>TypedString</string>
                    <key>Text</key><string>find</string>
                  </dict>
                  <dict>
                    <key>MacroTriggerType</key><string>HotKey</string>
                    <key>KeyCode</key><integer>3</integer>
                    <key>Modifiers</key><integer>256</integer>
                  </dict>
                </array>
              </dict></array>
            </dict>
          </array>
        </dict></plist>
        """)
        let parsed = KeyboardMaestroParser.parse(root)
        XCTAssertEqual(parsed.count, 3)
        XCTAssertEqual(parsed[0].combo, KeyCombo(keyCode: 40, modifiers: [.command, .shift]))
        XCTAssertEqual(parsed[0].action, "Global: Open")
        XCTAssertTrue(parsed[0].enabled)
        XCTAssertEqual(parsed[0].scope, .global)
        XCTAssertEqual(parsed[1].combo, KeyCombo(keyCode: 0, modifiers: [.command]))
        XCTAssertFalse(parsed[1].enabled)
        XCTAssertEqual(parsed[2].combo, KeyCombo(keyCode: 3, modifiers: [.command]))
        XCTAssertEqual(parsed[2].scope, .inApp)
        XCTAssertEqual(parsed[2].action, "Safari only: Find")
    }

    func testAlfredWorkflowAndLauncherHotkey() throws {
        let workflow = try plist("""
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
          <key>name</key><string>Dict</string>
          <key>disabled</key><false/>
          <key>objects</key>
          <array>
            <dict>
              <key>type</key><string>alfred.workflow.trigger.hotkey</string>
              <key>config</key>
              <dict>
                <key>hotkey</key><integer>49</integer>
                <key>hotmod</key><integer>131720</integer>
                <key>hotstring</key><string>Space</string>
              </dict>
            </dict>
            <dict>
              <key>type</key><string>alfred.workflow.trigger.hotkey</string>
              <key>config</key>
              <dict>
                <key>hotkey</key><integer>0</integer>
                <key>hotmod</key><integer>0</integer>
                <key>hotstring</key><string></string>
              </dict>
            </dict>
            <dict>
              <key>type</key><string>alfred.workflow.input.keyword</string>
              <key>config</key><dict><key>keyword</key><string>dict</string></dict>
            </dict>
          </array>
        </dict></plist>
        """)
        let shortcuts = AlfredParser.parseWorkflow(workflow as! [String: Any])
        XCTAssertEqual(shortcuts.count, 1)
        XCTAssertEqual(shortcuts[0].combo, KeyCombo(keyCode: 49, modifiers: [.shift]))
        XCTAssertEqual(shortcuts[0].action, "Dict")
        XCTAssertTrue(shortcuts[0].enabled)

        var disabled = workflow as! [String: Any]
        disabled["disabled"] = true
        XCTAssertFalse(AlfredParser.parseWorkflow(disabled)[0].enabled)

        let prefs = try plist("""
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
          <key>default</key>
          <dict>
            <key>key</key><integer>13</integer>
            <key>mod</key><integer>1048576</integer>
            <key>string</key><string>W</string>
          </dict>
          <key>unrelated</key>
          <dict>
            <key>key</key><string>not-a-keycode</string>
            <key>mod</key><integer>1</integer>
            <key>string</key><string>nope</string>
          </dict>
        </dict></plist>
        """)
        let launcher = AlfredParser.parseHotkeyPreferences(prefs, sourceName: "hotkey/prefs.plist")
        XCTAssertEqual(launcher.count, 1)
        XCTAssertEqual(launcher[0].combo, KeyCombo(keyCode: 13, modifiers: [.command]))
        XCTAssertEqual(launcher[0].action, "Главное сочетание Alfred")
        XCTAssertTrue(AlfredParser.parseHotkeyPreferences(prefs, sourceName: "features/clipboard/prefs.plist").isEmpty)
    }

    func testRaycastHotkeyShapes() throws {
        let root = try json("""
        {
          "hotkeys": [
            {"name": "Search Files", "hotkey": "option+space"},
            {"title": "Clipboard", "shortcut": "cmd+shift+v", "enabled": false}
          ],
          "commands": [
            {"name": "Window", "hotkey": {"keyCode": 49, "modifiers": ["command", "option"]}}
          ],
          "note": "not a hotkey"
        }
        """)
        let parsed = RaycastParser.parse(root)
        let search = parsed.first { $0.action == "Search Files" }
        let clipboard = parsed.first { $0.action == "Clipboard" }
        let window = parsed.first { $0.action == "Window" }
        XCTAssertEqual(parsed.count, 3)
        XCTAssertEqual(search?.combo, KeyCombo(keyCode: 49, modifiers: [.option]))
        XCTAssertEqual(clipboard?.combo, KeyCombo(keyCode: 9, modifiers: [.command, .shift]))
        XCTAssertEqual(clipboard?.enabled, false)
        XCTAssertEqual(window?.combo, KeyCombo(keyCode: 49, modifiers: [.command, .option]))
        XCTAssertFalse(parsed.contains { $0.action == "not a hotkey" || $0.source == "note" })
    }

    func testConfigStrategiesAreRegisteredForTheMethodToggle() {
        let ids: [DiscoveryMethod] = [.karabiner, .skhd, .hammerspoon, .betterTouchTool, .keyboardMaestro, .alfred, .raycast]
        for id in ids {
            let strategy = StrategyRegistry.strategy(id)
            XCTAssertNotNil(strategy, "\(id.rawValue) is missing from StrategyRegistry.all, so it has no toggle")
            XCTAssertEqual(strategy?.defaultEnabled, true)
            XCTAssertFalse(strategy?.displayName.isEmpty ?? true)
            XCTAssertFalse(strategy?.summary.isEmpty ?? true)
        }
        XCTAssertEqual(Set(StrategyRegistry.all.map(\.id)).count, StrategyRegistry.all.count)
        XCTAssertTrue(PreferencesScanStrategy.skippedDomains.contains("com.raycast.macos"))
        XCTAssertTrue(PreferencesScanStrategy.skippedDomains.contains("com.stairways.keyboardmaestro"))
    }

    private func json(_ text: String) throws -> Any {
        try JSONSerialization.jsonObject(with: Data(text.utf8))
    }

    private func plist(_ xml: String) throws -> Any {
        try PropertyListSerialization.propertyList(from: Data(xml.utf8), format: nil)
    }
}
