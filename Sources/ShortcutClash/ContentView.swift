import AppKit
import ShortcutClashCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar runs full height; the traffic lights float over its top strip.
            SidebarView(searchFocused: $searchFocused)
                .frame(width: Theme.Size.sidebarWidth)
            Rectangle().fill(Theme.hairline).frame(width: 1)
            VStack(spacing: 0) {
                AppToolbar()
                Rectangle().fill(Theme.hairline).frame(height: 1)
                DetailPane()
            }
        }
        .background { WindowBackdrop() }
        .background { WindowConfigurator() }
        .ignoresSafeArea(.container, edges: .top)
        .sheet(isPresented: $model.showCapture) {
            LiveCaptureView().environmentObject(model)
        }
        .sheet(isPresented: $model.showDiagnostics) {
            DiagnosticsView().environmentObject(model)
        }
        .background {
            // ⌘F focuses the search field.
            Button("") { searchFocused = true }
                .keyboardShortcut("f")
                .opacity(0)
                .accessibilityHidden(true)
        }
    }
}

/// Window background: base tone plus the faint accent tint that the translucent bars pick up.
private struct WindowBackdrop: View {
    var body: some View {
        ZStack {
            Theme.bg
            LinearGradient(colors: [Theme.tint.opacity(0.35), .clear], startPoint: .topLeading,
                           endPoint: UnitPoint(x: 0.6, y: 0.6))
        }
        .ignoresSafeArea()
    }
}

/// Hidden title bar with traffic lights floating over the toolbar; the toolbar drags the window.
private struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.styleMask.insert(.fullSizeContentView)
            window.backgroundColor = .clear
            WindowLog.record()
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}
}

/// Preview/screenshot helper: writes the app's window numbers so `screencapture -l` can target them.
enum WindowLog {
    static func record() {
        guard let path = ProcessInfo.processInfo.environment["SHORTCUTCLASH_WINDOW_LOG"] else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            let lines = NSApp.windows.filter(\.isVisible).map {
                "\($0.windowNumber)\t\(type(of: $0))\t\(Int($0.frame.width))x\(Int($0.frame.height))"
            }
            try? lines.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - Toolbar (52 px)

struct AppToolbar: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage(AppearanceMode.storageKey) private var appearance = AppearanceMode.system.rawValue

    var body: some View {
        HStack(spacing: 10) {
            Spacer(minLength: 12)
            SoftMenu(options: AppearanceMode.allCases.map { ($0.title, $0.rawValue) }, selection: $appearance, width: 104)
                .help("Appearance")
                .accessibilityLabel("Appearance")
            Button("Rescan") { model.rescan() }
                .softButton(.primary)
                .disabled(model.isScanning)
                .help("Run every enabled method again")
            let capturing = model.captureDisplay.isRunning
            Button {
                model.showCapture = true
            } label: {
                HStack(spacing: 6) {
                    if capturing { StatusDot(tone: .danger) }
                    Text(capturing ? "Capturing" : "Live capture")
                }
            }
            .softButton()
            .help("Press a shortcut and see who receives it")
            Button("Export JSON") { model.exportJSON() }
                .softButton()
                .help("Save the full report as JSON")
        }
        .padding(.trailing, 16)
        .frame(height: Theme.Size.toolbarHeight)
        .background { BarBackground(fill: Theme.toolbar) }
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject private var model: AppModel
    var searchFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: Theme.Size.toolbarHeight - 16) // traffic-light strip
            filters
            Rectangle().fill(Theme.hairline).frame(height: 1)
            listArea
            Rectangle().fill(Theme.hairline).frame(height: 1)
            SidebarFooter()
        }
        .background { BarBackground(fill: Theme.sidebar) }
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 12) {
            SearchField(text: $model.searchText, prompt: "Search: ⌘⇧K, app, action", focus: searchFocused)
            HStack(spacing: 10) {
                Toggle(isOn: $model.onlyConflicts) {
                    Text("Conflicts only").font(.system(size: 13)).foregroundStyle(Theme.fg)
                }
                .toggleStyle(.soft)
                Spacer(minLength: 8)
                Text("\(model.groups.count) combos")
                    .font(.system(size: 12)).foregroundStyle(Theme.muted)
                Text("·").font(.system(size: 12)).foregroundStyle(Theme.muted)
                Text("\(model.conflictCount) conflicts")
                    .font(.system(size: 12, weight: model.conflictCount > 0 ? .semibold : .regular))
                    .foregroundStyle(model.conflictCount > 0 ? Theme.danger : Theme.muted)
            }
            .frame(height: 24)
            HStack(spacing: 8) {
                SoftMenu(options: methodOptions, selection: $model.methodFilter)
                SoftMenu(options: appOptions, selection: $model.appFilter)
            }
        }
        .padding(16)
    }

    private var methodOptions: [(label: String, value: DiscoveryMethod?)] {
        [("All methods", nil)] + model.strategies.map { (StrategyRegistry.displayName($0.id), Optional($0.id)) }
    }

    private var appOptions: [(label: String, value: String?)] {
        [("All apps", nil)] + model.allOwners.map { ($0.name, Optional($0.key)) }
    }

    @ViewBuilder private var listArea: some View {
        let rows = model.filteredGroups
        if model.isScanning && model.groups.isEmpty {
            EmptyStateView(icon: .scan, tone: .accent, title: "Scanning shortcuts…",
                           message: "Reading system settings, app menus and config files. This takes a few seconds.")
        } else if model.scanFailed {
            EmptyStateView(icon: .warning, tone: .danger, title: "Scan failed",
                           message: "No detection method could read shortcuts. Check diagnostics for the reason, then try again.",
                           actions: [EmptyAction(title: "Try again", primary: true) { model.rescan() },
                                     EmptyAction(title: "Open diagnostics") { model.showDiagnostics = true }])
        } else if model.permissionNeeded {
            EmptyStateView(icon: .lock, tone: .warn, title: "Permission needed",
                           message: "Accessibility access lets ShortcutClash read app menus. Grant it in System Settings, then rescan.",
                           actions: [EmptyAction(title: "Grant access", primary: true) { model.requestAccessibility() },
                                     EmptyAction(title: "Open Settings") { Permissions.openSettings(for: .accessibility) }])
        } else if rows.isEmpty {
            if model.hasActiveFilters {
                EmptyStateView(icon: .search, tone: .muted, title: "No matching shortcuts",
                               message: model.trimmedQuery.isEmpty
                                   ? "No shortcut matches the selected method or app."
                                   : "Nothing matches “\(model.trimmedQuery)”. Try a key combination, an app name or an action.",
                               actions: [EmptyAction(title: "Clear filters") { model.clearFilters() }])
            } else if model.onlyConflicts && model.conflictCount == 0 {
                EmptyStateView(icon: .check, tone: .ok, title: "No conflicts found",
                               message: "Every shortcut found by the enabled methods has a single owner.",
                               actions: [EmptyAction(title: "Show all shortcuts") { model.onlyConflicts = false }])
            } else {
                EmptyStateView(icon: .search, tone: .muted, title: "No shortcuts found",
                               message: "Turn on more detection methods, then rescan.",
                               actions: [EmptyAction(title: "Detection methods", primary: true) { model.showMethods = true }])
            }
        } else {
            ShortcutList(rows: rows)
        }
    }
}

private struct ShortcutList: View {
    @EnvironmentObject private var model: AppModel
    @State private var showOthers = true
    let rows: [HotKeyGroup]

    private func row(_ group: HotKeyGroup) -> some View {
        GroupRow(group: group, showDuplicates: model.showDuplicates, selected: model.selection == group.id)
            .id(group.id)
            .onTapGesture { model.selection = group.id }
            .accessibilityAddTraits(.isButton)
            .accessibilityAddTraits(model.selection == group.id ? .isSelected : [])
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    let conflicts = rows.filter(\.isProblem)
                    let others = rows.filter { !$0.isProblem }
                    if !conflicts.isEmpty {
                        SectionCaps(text: "Conflicts · \(conflicts.count)", tone: .danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4).padding(.top, 4)
                    }
                    ForEach(conflicts) { row($0) }
                    if !others.isEmpty {
                        let open = showOthers || conflicts.isEmpty
                        Button { showOthers.toggle() } label: {
                            HStack(spacing: 4) {
                                SectionCaps(text: "Other shortcuts · \(others.count)")
                                Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Theme.muted).rotationEffect(.degrees(open ? 90 : 0))
                                Spacer()
                            }
                            .padding(.horizontal, 4).frame(height: 28).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).focusEffectDisabled().padding(.top, 8)
                        if open { ForEach(others) { row($0) } }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .focusable()
            .focusEffectDisabled()
            .onKeyPress(.downArrow) { move(1, proxy); return .handled }
            .onKeyPress(.upArrow) { move(-1, proxy); return .handled }
        }
    }

    private func move(_ delta: Int, _ proxy: ScrollViewProxy) {
        guard !rows.isEmpty else { return }
        let current = rows.firstIndex { $0.id == model.selection } ?? (delta > 0 ? -1 : rows.count)
        let next = min(max(current + delta, 0), rows.count - 1)
        model.selection = rows[next].id
        proxy.scrollTo(rows[next].id)
    }
}

struct GroupRow: View {
    let group: HotKeyGroup
    let showDuplicates: Bool
    let selected: Bool
    @State private var hovering = false

    private var allOff: Bool { group.findings.allSatisfy { !$0.enabled } }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
        HStack(spacing: 12) {
            Text(group.combo.display)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(allOff ? Theme.muted : Theme.fg)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: 104, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Text(group.owners.map(\.name).joined(separator: ", "))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.fg)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ViewThatFits(in: .horizontal) {
                    badges(limit: 3)
                    badges(limit: 2)
                    badges(limit: 1)
                }
            }
            trailing
                .frame(width: Theme.Size.bead, height: Theme.Size.bead)
        }
        .padding(.horizontal, 12)
        .frame(height: Theme.Size.row)
        .background(selected ? Theme.selected : (hovering ? Theme.hairline : .clear), in: shape)
        .overlay(shape.strokeBorder(selected ? Theme.accent.opacity(0.55) : .clear, lineWidth: 1))
        .contentShape(shape)
        .onHover { hovering = $0 }
        .softAnimation(Theme.Motion.hover, value: hovering)
        .accessibilityElement(children: .combine)
    }

    private func badges(limit: Int) -> some View {
        let methods = group.methods
        return HStack(spacing: 4) {
            ForEach(methods.prefix(limit)) { Badge(text: MethodShortName.of($0), tone: .accent) }
            if methods.count > limit { Badge(text: "+\(methods.count - limit)") }
            if allOff { Badge(text: "Off") }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var trailing: some View {
        switch group.status {
        case .conflict:
            CountBead(count: group.activeOwners.count)
                .help("Conflict: \(group.activeOwners.count) owners")
        case .layoutConflict:
            Image(systemName: "globe").foregroundStyle(Theme.warn).help("Layout conflict")
        case .inAppDuplicate where showDuplicates:
            Image(systemName: "square.on.square").foregroundStyle(Theme.muted).help("Duplicate inside one app")
        default:
            Color.clear
        }
    }
}

// MARK: - Footer: permissions, detection methods, diagnostics

struct SidebarFooter: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 0) {
                FooterLink(title: "Detection methods") { model.showMethods = true }
                    .popover(isPresented: $model.showMethods, arrowEdge: .top) {
                        MethodsView().environmentObject(model)
                    }
                Spacer(minLength: 8)
                Text("\(model.enabled.count) of \(model.strategies.count) enabled")
                    .font(.system(size: 12)).foregroundStyle(Theme.muted)
                    .padding(.trailing, 8)
                FooterLink(title: "Diagnostics") { model.showDiagnostics = true }
            }
            Rectangle().fill(Theme.hairline).frame(height: 1)
            PermissionBar()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

/// Quiet text link with a chevron; the only footer chrome.
struct FooterLink: View {
    let title: String
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.isFocused) private var isFocused

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title).font(.system(size: 12, weight: .medium))
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(hovering ? Theme.fg : Theme.muted)
            .padding(.horizontal, 6)
            .frame(height: 24)
            .overlay {
                if isFocused {
                    RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Theme.accent, lineWidth: 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .onHover { hovering = $0 }
    }
}

struct PermissionBar: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row(kind: .accessibility, granted: model.permissions.accessibility, request: model.requestAccessibility)
            row(kind: .inputMonitoring, granted: model.permissions.inputMonitoring, request: model.requestInputMonitoring)
            if model.permissions.secureInput {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield").foregroundStyle(Theme.warn)
                    Text("Secure Input is on: live capture will see nothing.")
                        .font(.system(size: 12)).foregroundStyle(Theme.warn)
                }
            }
        }
    }

    private func row(kind: PermissionKind, granted: Bool, request: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            StatusDot(tone: granted ? .ok : .warn)
            Text(kind.title).font(.system(size: 12)).foregroundStyle(Theme.fg)
            Text(granted ? "Granted" : "Needed")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(granted ? Theme.ok : Theme.warn)
            Spacer(minLength: 8)
            if !granted {
                Button("Request", action: request).softButton(small: true)
                Button("Settings") { Permissions.openSettings(for: kind) }.softButton(small: true)
            }
        }
        .frame(height: Theme.Size.buttonSmall)
        .accessibilityElement(children: .combine)
    }
}
