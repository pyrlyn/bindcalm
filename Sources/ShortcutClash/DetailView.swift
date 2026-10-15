import ShortcutClashCore
import SwiftUI

struct DetailView: View {
    @EnvironmentObject private var model: AppModel
    let group: HotKeyGroup

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if !model.layouts.layouts.isEmpty { layoutTable }
                if !group.layoutNotes.isEmpty { layoutNotes }
                ForEach(group.owners, id: \.key) { owner in
                    OwnerCard(owner: owner, findings: group.findings.filter { $0.owner.key == owner.key && $0.scope != .observed })
                }
                let observations = model.observations(for: group.combo)
                if !observations.isEmpty {
                    GroupBox("Живой захват") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(observations) { ObservationRow(observation: $0, registryOwners: group.owners) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(group.combo.display)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(group.combo.display).font(.system(size: 34, weight: .bold, design: .rounded))
                Badge(text: group.status.label, color: group.status.color)
            }
            Text(explanation).foregroundStyle(.secondary)
            if group.status == .conflict, let ranking = ShortcutRanking.winner(in: group.findings) {
                winnerLine(ranking)
            }
            HStack(spacing: 4) {
                Text("Обнаружено методами:").font(.caption).foregroundStyle(.secondary)
                ForEach(group.methods) { Badge(text: StrategyRegistry.displayName($0), color: .blue) }
            }
            Text("Код клавиши: \(group.combo.keyCode) · модификаторы: \(group.combo.modifiers.symbols.isEmpty ? "нет" : group.combo.modifiers.symbols)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    private func winnerLine(_ ranking: ShortcutWinner) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if ranking.isTie {
                Badge(text: "Победитель не определён", color: .orange)
            } else if let name = ranking.owners.first?.name {
                Badge(text: "Победитель: \(name)", color: .green)
            }
            Text(ranking.explanation).font(.callout)
        }
    }

    private var explanation: String {
        switch group.status {
        case .conflict:
            return "Сочетание заявлено несколькими владельцами, и хотя бы одно из них глобальное: срабатывает только одно."
        case .layoutConflict:
            return "Само по себе сочетание свободно, но в другой включённой раскладке символ попадает на занятую клавишу."
        case .inAppDuplicate:
            return "Одно приложение назначило это сочетание нескольким пунктам меню. Это не межпрограммный конфликт."
        case .none:
            return group.owners.count > 1
                ? "Несколько приложений используют сочетание только внутри себя — это не конфликт: работает то, что на переднем плане."
                : "Конфликтов не найдено."
        }
    }

    private var layoutTable: some View {
        GroupBox("Символ на этой клавише в раскладках") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                ForEach(model.layouts.layouts) { layout in
                    GridRow {
                        Text(layout.name + (layout.isCurrent ? " (текущая)" : ""))
                        Text(layout.unshifted[group.combo.keyCode] ?? "—").font(.body.monospaced())
                        Text(layout.isASCIICapable ? "латиница" : "не латиница").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var layoutNotes: some View {
        GroupBox("Раскладки") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(group.layoutNotes, id: \.self) { note in
                    Label(note.message, systemImage: note.isConflict ? "exclamationmark.triangle.fill" : "info.circle")
                        .foregroundStyle(note.isConflict ? .orange : .secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct OwnerCard: View {
    let owner: HotKeyOwner
    let findings: [DiscoveredHotKey]

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    if let path = owner.path {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable().frame(width: 32, height: 32)
                    } else {
                        Image(systemName: owner.kind == .system ? "apple.logo" : "questionmark.app")
                            .font(.title)
                            .frame(width: 32, height: 32)
                    }
                    VStack(alignment: .leading) {
                        Text(owner.name).font(.headline)
                        if let id = owner.bundleID { Text(id).font(.caption.monospaced()).foregroundStyle(.secondary) }
                        if let path = owner.path { Text(path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
                    }
                }
                ForEach(findings) { finding in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(finding.action ?? "—").font(.callout.weight(.medium))
                            if !finding.enabled { Badge(text: "выключено", color: .secondary) }
                        }
                        HStack(spacing: 6) {
                            Badge(text: StrategyRegistry.displayName(finding.method), color: .blue)
                            Badge(text: finding.confidence.label, color: finding.confidence.color)
                            Badge(text: finding.scope.label, color: finding.scope == .global ? .purple : .teal)
                        }
                        Text(finding.source)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(.leading, 42)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ObservationRow: View {
    let observation: LiveObservation
    let registryOwners: [HotKeyOwner]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(observation.combo.display).font(.body.weight(.semibold))
                Text(observation.time.formatted(date: .omitted, time: .standard)).font(.caption).foregroundStyle(.secondary)
                Spacer()
                flag("tap", observation.seenByTap)
                flag("глоб.", observation.seenByGlobalMonitor)
                flag("лок.", observation.seenByLocalMonitor)
            }
            Text(observation.verdictText).font(.callout)
                .foregroundStyle(observation.verdict == .swallowed ? .orange : .primary)
            Text("Активное приложение: \(observation.frontmost?.name ?? "—")"
                 + (observation.axFocusedApp.map { " · фокус AX: \($0)" } ?? ""))
                .font(.caption).foregroundStyle(.secondary)
            if !registryOwners.isEmpty {
                Text("В реестре: " + registryOwners.map(\.name).joined(separator: ", "))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func flag(_ title: String, _ on: Bool) -> some View {
        Badge(text: title, color: on ? .green : .secondary)
    }
}
