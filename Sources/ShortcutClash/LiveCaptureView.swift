import ShortcutClashCore
import SwiftUI

struct LiveCaptureView: View {
    @EnvironmentObject private var model: AppModel
    // Observed directly (not via the model) so the list re-renders on every recorded press.
    @ObservedObject var capture: LiveCaptureController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Живой захват").font(.title2.bold())
                Spacer()
                Button(capture.isRunning ? "Остановить" : "Начать запись") { model.toggleCapture() }
                Button("Очистить") { capture.clear() }
                Button("Закрыть") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text("Нажимайте сочетания (с ⌘, ⌃, ⌥ или F-клавиши). Обычный набор текста не записывается. Если нажатие видит только CGEvent tap, но не мониторы NSEvent, его, скорее всего, перехватило глобальное сочетание.")
                .font(.callout).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Toggle("CGEvent tap", isOn: model.binding(for: .cgEventTap))
                Toggle("Мониторы NSEvent", isOn: model.binding(for: .nsEventMonitor))
                Spacer()
                Badge(text: capture.tapActive ? "tap активен" : "tap выключен", color: capture.tapActive ? .green : .secondary)
                Badge(text: capture.monitorsActive ? "мониторы активны" : "мониторы выключены", color: capture.monitorsActive ? .green : .secondary)
            }
            .disabled(capture.isRunning)
            if let message = capture.lastMessage {
                Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.orange).font(.callout)
            }
            List(capture.observations) { observation in
                ObservationRow(observation: observation, registryOwners: model.registryOwners(for: observation.combo))
            }
            .overlay {
                if capture.observations.isEmpty {
                    Text(capture.isRunning ? "Ожидание нажатий…" : "Запись не идёт").foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(width: 640, height: 520)
    }
}
