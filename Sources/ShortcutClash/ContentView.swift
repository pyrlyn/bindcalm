import ShortcutClashCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showMethods = false
    @State private var showCapture = false
    @State private var showDiagnostics = false

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 340, ideal: 400)
        } detail: {
            if let group = model.group(with: model.selection) {
                DetailView(group: group)
            } else {
                ContentUnavailableView("Выберите сочетание",
                                       systemImage: "keyboard",
                                       description: Text("Слева — все найденные сочетания, сгруппированные по комбинации клавиш. Красный значок — конфликт."))
            }
        }
        .searchable(text: $model.searchText, placement: .sidebar, prompt: "Поиск: ⌘⇧K, приложение, действие")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    model.rescan()
                } label: {
                    Label("Пересканировать", systemImage: "arrow.clockwise")
                }
                .disabled(model.isScanning)
                .help("Запустить все включённые методы заново")

                Button {
                    model.toggleCapture()
                    if model.capture.isRunning { showCapture = true }
                } label: {
                    Label(model.capture.isRunning ? "Остановить захват" : "Живой захват",
                          systemImage: model.capture.isRunning ? "stop.circle.fill" : "record.circle")
                }
                .help("Режим записи: нажмите сочетание и посмотрите, кто его получает")

                Button {
                    showCapture = true
                } label: {
                    Label("Журнал захвата", systemImage: "list.bullet.rectangle")
                }

                Button {
                    model.requestAccessibility()
                } label: {
                    Label("Запросить универсальный доступ", systemImage: "hand.raised")
                }
                .disabled(model.permissions.accessibility)
                .help("Нужен для чтения меню приложений и глобального монитора NSEvent")

                Button {
                    showMethods = true
                } label: {
                    Label("Методы", systemImage: "slider.horizontal.3")
                }
                .popover(isPresented: $showMethods, arrowEdge: .bottom) {
                    MethodsView().environmentObject(model)
                }

                Button {
                    showDiagnostics = true
                } label: {
                    Label("Диагностика", systemImage: "stethoscope")
                }

                Button {
                    model.exportJSON()
                } label: {
                    Label("Экспорт JSON", systemImage: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showCapture) {
            LiveCaptureView(capture: model.capture).environmentObject(model)
        }
        .sheet(isPresented: $showDiagnostics) {
            DiagnosticsView().environmentObject(model)
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            filters
            Divider()
            List(model.filteredGroups, selection: $model.selection) { group in
                GroupRow(group: group, showDuplicates: model.showDuplicates)
                    .tag(group.id)
            }
            .overlay {
                if model.isScanning && model.groups.isEmpty {
                    ProgressView("Сканирование…")
                } else if !model.isScanning && model.filteredGroups.isEmpty {
                    Text("Ничего не найдено").foregroundStyle(.secondary)
                }
            }
            Divider()
            PermissionBar()
        }
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("Только конфликты", isOn: $model.onlyConflicts)
                    .toggleStyle(.switch)
                Spacer()
                if model.isScanning { ProgressView().controlSize(.small) }
                Text("\(model.groups.count) сочетаний · \(model.conflictCount) конфликтов")
                    .font(.caption)
                    .foregroundStyle(model.conflictCount > 0 ? .red : .secondary)
            }
            HStack {
                Picker("Метод", selection: $model.methodFilter) {
                    Text("Все методы").tag(DiscoveryMethod?.none)
                    ForEach(model.strategies.map(\.id)) { method in
                        Text(StrategyRegistry.displayName(method)).tag(DiscoveryMethod?.some(method))
                    }
                }
                Picker("Приложение", selection: $model.appFilter) {
                    Text("Все приложения").tag(String?.none)
                    ForEach(model.allOwners, id: \.key) { owner in
                        Text(owner.name).tag(String?.some(owner.key))
                    }
                }
            }
            .labelsHidden()
        }
        .padding(10)
    }
}

struct GroupRow: View {
    let group: HotKeyGroup
    let showDuplicates: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(group.combo.display)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .frame(minWidth: 90, alignment: .leading)
                .foregroundStyle(group.findings.allSatisfy { !$0.enabled } ? .secondary : .primary)
            VStack(alignment: .leading, spacing: 3) {
                Text(group.owners.map(\.name).joined(separator: ", "))
                    .lineLimit(2)
                    .font(.callout)
                HStack(spacing: 4) {
                    ForEach(group.methods) { method in
                        Badge(text: MethodShortName.of(method), color: .blue)
                    }
                    if group.findings.allSatisfy({ !$0.enabled }) {
                        Badge(text: "выключено", color: .secondary)
                    }
                }
            }
            Spacer()
            statusBadge
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder private var statusBadge: some View {
        switch group.status {
        case .conflict:
            Text("\(group.activeOwners.count)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(minWidth: 20, minHeight: 20)
                .background(Circle().fill(.red))
                .help("Конфликт: \(group.activeOwners.count) владельцев")
        case .layoutConflict:
            Image(systemName: "globe").foregroundStyle(.orange).help("Конфликт из-за раскладки")
        case .inAppDuplicate where showDuplicates:
            Image(systemName: "square.on.square").foregroundStyle(.secondary).help("Дубль внутри одного приложения")
        default:
            EmptyView()
        }
    }
}

enum MethodShortName {
    static func of(_ method: DiscoveryMethod) -> String {
        switch method {
        case .symbolicHotKeys: return "plist"
        case .skyLightSymbolic: return "SkyLight"
        case .carbonProbe: return "Carbon"
        case .userKeyEquivalents: return "NSUserKeyEq"
        case .preferencesScan: return "prefs"
        case .sandboxPreferences: return "sandbox"
        case .services: return "Службы"
        case .karabiner: return "Karabiner"
        case .skhd: return "skhd"
        case .hammerspoon: return "HS"
        case .betterTouchTool: return "BTT"
        case .keyboardMaestro: return "KM"
        case .alfred: return "Alfred"
        case .raycast: return "Raycast"
        case .accessibilityMenus: return "AX"
        case .systemKeys: return "HIToolbox"
        case .nsEventMonitor: return "NSEvent"
        case .cgEventTap: return "tap"
        }
    }
}

struct PermissionBar: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            row(title: "Универсальный доступ", granted: model.permissions.accessibility,
                request: model.requestAccessibility, kind: .accessibility)
            row(title: "Мониторинг ввода", granted: model.permissions.inputMonitoring,
                request: model.requestInputMonitoring, kind: .inputMonitoring)
            if model.permissions.secureInput {
                Label("Включён защищённый ввод — живой захват ничего не увидит", systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(10)
    }

    private func row(title: String, granted: Bool, request: @escaping () -> Void, kind: PermissionKind) -> some View {
        HStack(spacing: 6) {
            Image(systemName: granted ? "checkmark.shield.fill" : "xmark.shield")
                .foregroundStyle(granted ? .green : .orange)
            Text(title).font(.caption)
            Text(granted ? "есть" : "нет").font(.caption.bold()).foregroundStyle(granted ? .green : .orange)
            Spacer()
            if !granted {
                Button("Запросить", action: request).controlSize(.small)
                Button("Настройки") { Permissions.openSettings(for: kind) }.controlSize(.small)
            }
        }
    }
}
