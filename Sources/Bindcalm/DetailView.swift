import AppKit
import BindcalmCore
import SwiftUI

/// Solid detail pane: the selected group, or the nothing-selected empty state.
struct DetailPane: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if let group = model.group(with: model.selection) {
                DetailView(group: group)
            } else {
                EmptyStateView(icon: .cursor, tone: .accent, title: "Select a shortcut",
                               message: "Pick a shortcut on the left to see who owns it and how it was detected.")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surface)
    }
}

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
                    VStack(alignment: .leading, spacing: 12) {
                        SectionCaps(text: "Live capture")
                        ForEach(Array(observations.enumerated()), id: \.element.id) { index, item in
                            if index > 0 { Rectangle().fill(Theme.hairline).frame(height: 1) }
                            ObservationRow(observation: item, registryOwners: group.owners)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .softCard(padding: 16)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Text(group.combo.display)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.fg)
                Badge(text: group.status.label, tone: group.status.tone)
            }
            Text(explanation)
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            if group.status == .conflict, let ranking = ShortcutRanking.winner(in: group.findings) {
                winnerLine(ranking)
            }
            HStack(alignment: .center, spacing: 8) {
                Text("Detected by:").font(.system(size: 12)).foregroundStyle(Theme.muted)
                FlowLayout {
                    ForEach(group.methods) { Badge(text: MethodShortName.of($0), tone: .accent) }
                }
            }
            Text("Key code: \(group.combo.keyCode) · modifiers: \(group.combo.modifiers.symbols.isEmpty ? "none" : group.combo.modifiers.symbols)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.muted)
        }
    }

    private func winnerLine(_ ranking: ShortcutWinner) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if ranking.isTie {
                Badge(text: "No clear winner", tone: .warn)
            } else if let name = ranking.owners.first?.name {
                Badge(text: "Winner: \(name)", tone: .ok)
            }
            Text(ranking.explanation)
                .font(.system(size: 13))
                .foregroundStyle(Theme.fg)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }

    private var explanation: String {
        switch group.status {
        case .conflict:
            return "This shortcut is claimed by several owners, and at least one of them is global, so only one of them will fire."
        case .layoutConflict:
            return "The shortcut itself is free, but in another enabled keyboard layout its character lands on a key that is already taken."
        case .inAppDuplicate:
            return "One app assigned this shortcut to several of its menu items. This is not a cross-app conflict."
        case .none:
            return group.owners.count > 1
                ? "Several apps use this shortcut only inside themselves. That is not a conflict: whichever is in front wins."
                : "No conflicts found."
        }
    }

    private var layoutTable: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionCaps(text: "Character on this key per layout")
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                ForEach(model.layouts.layouts) { layout in
                    GridRow {
                        Text(layout.name + (layout.isCurrent ? " (current)" : ""))
                            .font(.system(size: 13)).foregroundStyle(Theme.fg)
                        Text(layout.unshifted[group.combo.keyCode] ?? "—")
                            .font(.system(size: 13, design: .monospaced)).foregroundStyle(Theme.fg)
                        Text(layout.isASCIICapable ? "Latin" : "Non-Latin")
                            .font(.system(size: 12)).foregroundStyle(Theme.muted)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard(padding: 16)
    }

    private var layoutNotes: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionCaps(text: "Layouts")
            ForEach(group.layoutNotes, id: \.self) { note in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: note.isConflict ? "exclamationmark.triangle.fill" : "info.circle")
                        .foregroundStyle(note.isConflict ? Theme.warn : Theme.muted)
                    Text(note.message).font(.system(size: 13)).foregroundStyle(Theme.fg)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard(padding: 16)
    }
}

struct OwnerCard: View {
    let owner: HotKeyOwner
    let findings: [DiscoveredHotKey]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                avatar
                VStack(alignment: .leading, spacing: 2) {
                    Text(owner.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.fg)
                    if let id = owner.bundleID {
                        Text(id).font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.muted)
                    }
                    if let path = owner.path {
                        Text(path).font(.system(size: 12)).foregroundStyle(Theme.muted).textSelection(.enabled)
                    }
                }
            }
            ForEach(Array(findings.enumerated()), id: \.element.id) { index, finding in
                Rectangle().fill(Theme.hairline).frame(height: 1)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(finding.action ?? "—").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.fg)
                        if !finding.enabled { Badge(text: "Off") }
                    }
                    FlowLayout {
                        Badge(text: StrategyRegistry.displayName(finding.method), tone: .accent)
                        Badge(text: finding.confidence.label, tone: finding.confidence.tone)
                        Badge(text: finding.scope.label, tone: finding.scope.tone)
                    }
                    Text(finding.source)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.muted)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard(padding: 16)
    }

    @ViewBuilder private var avatar: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        if let path = owner.path {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable().frame(width: 36, height: 36)
        } else {
            ZStack {
                shape.fill(Theme.accent.opacity(0.14))
                shape.strokeBorder(Theme.accent.opacity(0.32), lineWidth: 1)
                if owner.kind == .system {
                    Image(systemName: "apple.logo").font(.system(size: 16)).foregroundStyle(Theme.accent)
                } else {
                    Text(String(owner.name.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.accent)
                }
            }
            .frame(width: 36, height: 36)
        }
    }
}

struct ObservationRow: View {
    let observation: LiveObservation
    let registryOwners: [HotKeyOwner]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(observation.combo.display)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.fg)
                Text(observation.time.formatted(date: .omitted, time: .standard))
                    .font(.system(size: 12)).foregroundStyle(Theme.muted)
                Spacer(minLength: 8)
                flag("tap", observation.seenByTap)
                flag("global", observation.seenByGlobalMonitor)
                flag("local", observation.seenByLocalMonitor)
            }
            Text(observation.verdictText)
                .font(.system(size: 13))
                .foregroundStyle(observation.verdict == .swallowed ? Theme.warn : Theme.fg)
            Text("Frontmost app: \(observation.frontmost?.name ?? "—")"
                 + (observation.axFocusedApp.map { " · AX focus: \($0)" } ?? ""))
                .font(.system(size: 12)).foregroundStyle(Theme.muted)
            if !registryOwners.isEmpty {
                Text("In registry: " + registryOwners.map(\.name).joined(separator: ", "))
                    .font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func flag(_ title: String, _ on: Bool) -> some View {
        Badge(text: title, tone: on ? .ok : .muted)
    }
}
