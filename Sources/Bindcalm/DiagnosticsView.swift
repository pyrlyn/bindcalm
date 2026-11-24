import BindcalmCore
import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject private var model: AppModel
    private let symbols = PrivateSymbols.probeAll()

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Diagnostics") { EmptyView() }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    card("Permissions") {
                        statusRow("Accessibility", model.permissions.accessibility ? "Granted" : "Not granted",
                                  model.permissions.accessibility ? .ok : .warn)
                        statusRow("Input Monitoring", model.permissions.inputMonitoring ? "Granted" : "Not granted",
                                  model.permissions.inputMonitoring ? .ok : .warn)
                        statusRow("Secure Input", model.permissions.secureInput ? "On" : "Off",
                                  model.permissions.secureInput ? .warn : .ok)
                        Text("The app is signed ad hoc: after a rebuild macOS may treat it as a new app and reset these permissions.")
                            .font(.system(size: 12)).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    card("Keyboard layouts") {
                        ForEach(model.layouts.layouts) { layout in
                            HStack(spacing: 8) {
                                Text(layout.name + (layout.isCurrent ? " — current" : ""))
                                    .font(.system(size: 13)).foregroundStyle(Theme.fg)
                                Spacer(minLength: 8)
                                Text(layout.id).font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.muted)
                            }
                        }
                        Text("Automatic input source switching per document: \(perDocumentText)")
                            .font(.system(size: 12)).foregroundStyle(Theme.muted)
                    }
                    card("Private and undocumented symbols (dlsym)") {
                        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                            ForEach(symbols, id: \.name) { symbol in
                                GridRow {
                                    StatusDot(tone: symbol.found ? .ok : .muted)
                                    Text(symbol.name).font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.fg)
                                    Text(symbol.image ?? "—").font(.system(size: 12)).foregroundStyle(Theme.muted)
                                        .lineLimit(1).truncationMode(.middle)
                                }
                            }
                        }
                    }
                    card("Method results") {
                        if model.results.isEmpty {
                            Text("No scan has finished yet.").font(.system(size: 13)).foregroundStyle(Theme.muted)
                        }
                        ForEach(model.results) { result in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                StatusDot(tone: result.state.tone)
                                Text(result.displayName).font(.system(size: 13)).foregroundStyle(Theme.fg)
                                Spacer(minLength: 8)
                                Text("\(result.state.label) · \(result.count) · \(result.durationMs) ms"
                                     + (result.message.map { " · \($0)" } ?? ""))
                                    .font(.system(size: 12)).foregroundStyle(result.state.tone.color)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 640, height: 560)
        .background(Theme.surface)
    }

    private func card<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionCaps(text: title)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard(padding: 16)
    }

    private func statusRow(_ title: String, _ value: String, _ tone: Tone) -> some View {
        HStack(spacing: 8) {
            StatusDot(tone: tone)
            Text(title).font(.system(size: 13)).foregroundStyle(Theme.fg)
            Spacer(minLength: 8)
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundStyle(tone.color)
        }
    }

    private var perDocumentText: String {
        switch model.layouts.perDocumentInputSource {
        case .some(true): return "on"
        case .some(false): return "off"
        case .none: return "unknown"
        }
    }
}
