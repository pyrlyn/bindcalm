import AppKit
import SwiftUI

struct BindcalmApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel()
    @AppStorage(AppearanceMode.storageKey) private var appearance = AppearanceMode.system.rawValue

    private var mode: AppearanceMode { AppearanceMode(rawValue: appearance) ?? .system }

    var body: some Scene {
        WindowGroup("Bindcalm") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 960, minHeight: 600)
                .preferredColorScheme(mode.colorScheme)
                .onAppear { applyAppearance() }
                .onChange(of: appearance) { _, _ in applyAppearance() }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Rescan") { model.rescan() }
                    .keyboardShortcut("r")
                Button("Export JSON…") { model.exportJSON() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
            }
            CommandGroup(after: .toolbar) {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppearanceMode.allCases) { Text($0.title).tag($0.rawValue) }
                }
                Divider()
                Button("Detection Methods…") { model.showMethods = true }
                    .keyboardShortcut("m", modifiers: [.command, .shift])
                Button("Live Capture…") { model.showCapture = true }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                Button("Diagnostics…") { model.showDiagnostics = true }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
            }
        }
    }

    /// Drives every window (sheets and popovers included) so the dynamic Theme colors resolve correctly.
    private func applyAppearance() {
        switch mode {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when launched as a bare SwiftPM binary (no bundle): otherwise no Dock icon or menu bar.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
