import ShortcutClashCore
import SwiftUI

struct MethodsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Методы обнаружения").font(.headline)
                Spacer()
                Button("Пересканировать") { model.rescan() }.disabled(model.isScanning)
            }
            .padding(12)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(model.strategies, id: \.id) { strategy in
                        MethodRow(strategy: strategy, result: model.result(for: strategy.id), isOn: model.binding(for: strategy.id))
                    }
                    Divider()
                    Toggle(isOn: $model.layoutAnalysis) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Анализ раскладок (TIS + UCKeyTranslate)").font(.callout.weight(.medium))
                            Text("Показывает символ клавиши в каждой включённой раскладке и ищет конфликты, когда символ из меню в другой раскладке попадает на клавишу, занятую глобальным сочетанием.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Toggle(isOn: $model.showDuplicates) {
                        Text("Показывать дубли внутри одного приложения").font(.callout.weight(.medium))
                    }
                }
                .padding(12)
            }
        }
        .frame(width: 520, height: 600)
    }
}

struct MethodRow: View {
    let strategy: any HotKeyDiscoveryStrategy
    let result: StrategyRunResult?
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(strategy.displayName).font(.callout.weight(.medium))
                    if let permission = strategy.requiredPermission {
                        Badge(text: permission == .accessibility ? "Универсальный доступ" : "Мониторинг ввода", color: .orange)
                    }
                    if strategy.isLiveCapture { Badge(text: "живой захват", color: .purple) }
                }
                Text(strategy.summary).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if let result {
                    Label("\(result.state.label) · \(result.count) · \(result.durationMs) мс" + (result.message.map { " · \($0)" } ?? ""),
                          systemImage: result.state.symbol)
                        .font(.caption)
                        .foregroundStyle(result.state.color)
                }
            }
        }
    }
}
