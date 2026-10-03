import ShortcutClashCore
import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    private let symbols = PrivateSymbols.probeAll()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Диагностика").font(.title2.bold())
                Spacer()
                Button("Закрыть") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    GroupBox("Разрешения") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Универсальный доступ: \(model.permissions.accessibility ? "есть" : "нет")")
                            Text("Мониторинг ввода: \(model.permissions.inputMonitoring ? "есть" : "нет")")
                            Text("Защищённый ввод (Secure Input): \(model.permissions.secureInput ? "включён" : "выключен")")
                            Text("Приложение подписано ad-hoc: после пересборки macOS может считать его новым и сбросить разрешения.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    GroupBox("Раскладки клавиатуры") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(model.layouts.layouts) { layout in
                                Text("\(layout.name)\(layout.isCurrent ? " — текущая" : "") · \(layout.id)").font(.callout)
                            }
                            Text("Автопереключение источника ввода по документу: \(perDocumentText)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    GroupBox("Приватные и недокументированные символы (dlsym)") {
                        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                            ForEach(symbols, id: \.name) { symbol in
                                GridRow {
                                    Image(systemName: symbol.found ? "checkmark.circle.fill" : "xmark.circle")
                                        .foregroundStyle(symbol.found ? .green : .secondary)
                                    Text(symbol.name).font(.caption.monospaced())
                                    Text(symbol.image ?? "—").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    GroupBox("Результаты методов") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(model.results) { result in
                                Label("\(result.displayName): \(result.state.label), \(result.count), \(result.durationMs) мс"
                                      + (result.message.map { " — \($0)" } ?? ""), systemImage: result.state.symbol)
                                    .foregroundStyle(result.state.color)
                                    .font(.callout)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 640, height: 560)
    }

    private var perDocumentText: String {
        switch model.layouts.perDocumentInputSource {
        case .some(true): return "включено"
        case .some(false): return "выключено"
        case .none: return "неизвестно"
        }
    }
}
