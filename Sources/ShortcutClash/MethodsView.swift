import ShortcutClashCore
import SwiftUI

/// "Detection methods" popover.
struct MethodsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Detection methods").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.fg)
                Spacer()
                Button("Rescan") { model.rescan() }.softButton(small: true).disabled(model.isScanning)
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            Rectangle().fill(Theme.hairline).frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(model.strategies.enumerated()), id: \.element.id) { index, strategy in
                        if index > 0 { Rectangle().fill(Theme.hairline).frame(height: 1) }
                        MethodRow(strategy: strategy, result: model.result(for: strategy.id), isOn: model.binding(for: strategy.id))
                            .padding(.vertical, 12)
                    }
                    Rectangle().fill(Theme.border).frame(height: 1).padding(.vertical, 4)
                    OptionRow(title: "Keyboard layout analysis (TIS + UCKeyTranslate)",
                              detail: "Shows the key's character in every enabled layout and finds conflicts where a menu character in another layout lands on a globally owned key.",
                              isOn: $model.layoutAnalysis)
                        .padding(.vertical, 12)
                    Rectangle().fill(Theme.hairline).frame(height: 1)
                    OptionRow(title: "Show duplicates inside one app", detail: nil, isOn: $model.showDuplicates)
                        .padding(.vertical, 12)
                }
                .padding(.horizontal, 16)
            }
        }
        .frame(width: 520, height: 600)
        .background(Theme.surface)
    }
}

private struct OptionRow: View {
    let title: String
    let detail: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.fg)
                if let detail {
                    Text(detail).font(.system(size: 12)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            Toggle(isOn: $isOn) { EmptyView() }.labelsHidden().toggleStyle(.soft)
        }
    }
}

struct MethodRow: View {
    let strategy: any HotKeyDiscoveryStrategy
    let result: StrategyRunResult?
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(strategy.displayName).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.fg)
                    if let permission = strategy.requiredPermission { Badge(text: permission.title, tone: .warn) }
                    if strategy.isLiveCapture { Badge(text: "Live capture", tone: .accent) }
                }
                Text(strategy.summary).font(.system(size: 12)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if let result {
                    HStack(spacing: 6) {
                        StatusDot(tone: result.state.tone)
                        Text("\(result.state.label) · \(result.count) · \(result.durationMs) ms"
                             + (result.message.map { " · \($0)" } ?? ""))
                            .font(.system(size: 12)).foregroundStyle(result.state.tone.color)
                    }
                }
            }
            Spacer(minLength: 8)
            Toggle(isOn: $isOn) { EmptyView() }.labelsHidden().toggleStyle(.soft)
                .padding(.top, 1)
                .accessibilityLabel(strategy.displayName)
        }
    }
}
