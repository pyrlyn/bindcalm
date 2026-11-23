import BindcalmCore
import SwiftUI

/// Shared header for sheets: title left, Close right, 52 px, hairline below.
struct SheetHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(title).font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.fg)
                Spacer()
                trailing
                Button("Close") { dismiss() }.softButton().keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .frame(height: 56)
            Rectangle().fill(Theme.hairline).frame(height: 1)
        }
    }
}

struct LiveCaptureView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View { Content(model: model, capture: model.capture) }

    /// Observes the controller directly so the log re-renders on every recorded press.
    private struct Content: View {
        let model: AppModel
        @ObservedObject var capture: LiveCaptureController

        var body: some View {
            let display = model.captureDisplay
            VStack(spacing: 0) {
                SheetHeader(title: "Live capture") {
                    Button("Clear") { model.clearCapture() }.softButton().disabled(display.observations.isEmpty)
                    Button(display.isRunning ? "Stop" : "Start recording") { model.toggleCapture() }
                        .softButton(.primary, error: display.isRunning)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Press shortcuts with ⌘, ⌃, ⌥ or F-keys. Ordinary typing is never recorded. If only the CGEvent tap sees a press and the NSEvent monitors do not, a global shortcut most likely took it.")
                        .font(.system(size: 13)).foregroundStyle(Theme.muted)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 16) {
                        Toggle(isOn: model.binding(for: .cgEventTap)) {
                            Text("CGEvent tap").font(.system(size: 13)).foregroundStyle(Theme.fg)
                        }.toggleStyle(.soft)
                        Toggle(isOn: model.binding(for: .nsEventMonitor)) {
                            Text("NSEvent monitors").font(.system(size: 13)).foregroundStyle(Theme.fg)
                        }.toggleStyle(.soft)
                        Spacer(minLength: 8)
                        Badge(text: display.tapActive ? "Tap active" : "Tap off", tone: display.tapActive ? .ok : .muted)
                        Badge(text: display.monitorsActive ? "Monitors active" : "Monitors off",
                              tone: display.monitorsActive ? .ok : .muted)
                    }
                    .disabled(display.isRunning)
                    if let message = display.message {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle").foregroundStyle(Theme.warn)
                            Text(message).font(.system(size: 13)).foregroundStyle(Theme.warn)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(20)
                Rectangle().fill(Theme.hairline).frame(height: 1)
                logArea(display)
            }
            .frame(width: 640, height: 520)
            .background(Theme.surface)
        }

        @ViewBuilder private func logArea(_ display: CaptureDisplay) -> some View {
            if display.observations.isEmpty {
                if display.isRunning {
                    EmptyStateView(icon: .record, tone: .accent, title: "Waiting for key presses…",
                                   message: "Press a shortcut with ⌘, ^, ⌥ or an F-key. Plain typing is not recorded.",
                                   actions: [EmptyAction(title: "Stop") { model.toggleCapture() }])
                } else {
                    EmptyStateView(icon: .record, tone: .muted, title: "Live capture is off",
                                   message: "Start recording, then press a shortcut to see whether a global interceptor takes it.",
                                   actions: [EmptyAction(title: "Start recording", primary: true) { model.toggleCapture() }])
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(display.observations.enumerated()), id: \.element.id) { index, item in
                            if index > 0 { Rectangle().fill(Theme.hairline).frame(height: 1) }
                            ObservationRow(observation: item, registryOwners: model.registryOwners(for: item.combo))
                                .padding(.vertical, 12)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}
