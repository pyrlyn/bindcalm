import AppKit
import SwiftUI

// MARK: - Motion

extension View {
    /// Animates only when the user has not asked for reduced motion.
    func softAnimation<V: Equatable>(_ duration: Double, value: V) -> some View {
        modifier(SoftAnimation(duration: duration, value: value))
    }
}

private struct SoftAnimation<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let duration: Double
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : .easeOut(duration: duration), value: value)
    }
}

// MARK: - Surfaces

/// Translucent bar fill (sidebar, toolbar): a light blur under a 88-92% opaque tone. With
/// Reduce Transparency it becomes a solid fill.
struct BarBackground: View {
    let fill: Color
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if reduceTransparency {
            Theme.opaque
        } else {
            ZStack {
                VisualEffectView(material: .sidebar, blending: .withinWindow)
                fill
            }
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blending: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.state = .active
        view.material = material
        view.blendingMode = blending
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blending
    }
}

extension View {
    /// Solid card: 1 px border, one soft shadow.
    func softCard(padding: CGFloat = 0) -> some View {
        modifier(SoftCard(padding: padding))
    }
}

private struct SoftCard: ViewModifier {
    let padding: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
        content
            .padding(padding)
            .background(reduceTransparency ? Theme.opaqueRaised : Theme.card, in: shape)
            .overlay(shape.strokeBorder(reduceTransparency ? Theme.opaqueBorder : Theme.border, lineWidth: 1))
            .shadow(color: Theme.shadowSoft, radius: 4, y: 2)
    }
}

// MARK: - Buttons

enum SoftButtonKind { case secondary, primary }

struct SoftButtonStyle: ButtonStyle {
    var kind: SoftButtonKind = .secondary
    var small = false
    var error = false

    func makeBody(configuration: Configuration) -> some View {
        SoftButtonBody(configuration: configuration, kind: kind, small: small, error: error)
    }
}

private struct SoftButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let kind: SoftButtonKind
    let small: Bool
    let error: Bool

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
        let pressed = configuration.isPressed
        let hot = hovering && isEnabled && !pressed
        let primary = kind == .primary

        configuration.label
            .font(.system(size: small ? 12 : 13, weight: .medium))
            .foregroundStyle(textColor)
            .padding(.horizontal, small ? 13 : 15)
            .frame(height: small ? Theme.Size.buttonSmall : Theme.Size.button)
            .background(fill(hot: hot, pressed: pressed), in: shape)
            .overlay(shape.strokeBorder(borderColor, lineWidth: 1))
            // 1 px inner highlight on the top edge.
            .overlay(
                shape.inset(by: 1).strokeBorder(
                    LinearGradient(colors: [primary ? Theme.primaryHighlight : Theme.highlight, .clear],
                                   startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.3)),
                    lineWidth: 1)
            )
            // Pressed: small inner shadow instead of the lift.
            .overlay(
                shape.fill(LinearGradient(colors: [Theme.inset, .clear], startPoint: .top,
                                          endPoint: UnitPoint(x: 0.5, y: 0.35)))
                    .opacity(pressed ? 1 : 0)
            )
            .shadow(color: pressed ? .clear : Theme.shadow, radius: hot ? 4 : 1, y: hot ? 3 : 1)
            .overlay {
                if isFocused {
                    RoundedRectangle(cornerRadius: Theme.Radius.control + 4, style: .continuous)
                        .strokeBorder(Theme.accent, lineWidth: 2)
                        .padding(-4)
                }
            }
            .offset(y: hot && !reduceMotion ? -1 : 0)
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(shape)
            .onHover { hovering = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: pressed ? Theme.Motion.press : Theme.Motion.hover),
                       value: hot)
            .animation(reduceMotion ? nil : .easeOut(duration: pressed ? Theme.Motion.press : Theme.Motion.release),
                       value: pressed)
    }

    private var textColor: Color {
        if kind == .primary { return error ? Theme.onDanger : Theme.onAccent }
        return error ? Theme.danger : Theme.fg
    }

    private var borderColor: Color {
        if kind == .primary { return Color.black.opacity(0.18) }
        return error ? Theme.danger : Theme.border
    }

    private func fill(hot: Bool, pressed: Bool) -> AnyShapeStyle {
        if kind == .primary {
            if error { return AnyShapeStyle(Theme.dangerFill) }
            return AnyShapeStyle(LinearGradient(colors: [Theme.primaryTop, Theme.primaryBottom],
                                                startPoint: .top, endPoint: .bottom))
        }
        return AnyShapeStyle(pressed ? Theme.controlActive : (hot ? Theme.controlHover : Theme.control))
    }
}

extension View {
    func softButton(_ kind: SoftButtonKind = .secondary, small: Bool = false, error: Bool = false) -> some View {
        buttonStyle(SoftButtonStyle(kind: kind, small: small, error: error)).focusEffectDisabled()
    }
}

// MARK: - Fields

/// Recessed search field: solid input fill, 1 px border, inner shadow; accent border and a soft ring on focus.
struct SearchField: View {
    @Binding var text: String
    let prompt: String
    var focus: FocusState<Bool>.Binding

    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
        let focused = focus.wrappedValue
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.muted)
                .frame(width: 14, height: 14)
            TextField("", text: $text, prompt: Text(prompt).foregroundStyle(Theme.muted))
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Theme.fg)
                .focused(focus)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: Theme.Size.field)
        .background(hovering && !focused ? Theme.controlHover : Theme.input, in: shape)
        .overlay(shape.fill(LinearGradient(colors: [Theme.inset.opacity(0.5), .clear], startPoint: .top,
                                           endPoint: UnitPoint(x: 0.5, y: 0.14))).allowsHitTesting(false))
        .overlay(shape.strokeBorder(focused ? Theme.accent : (hovering ? Theme.borderStrong : Theme.border),
                                    lineWidth: focused ? 1.5 : 1))
        .overlay {
            if focused {
                RoundedRectangle(cornerRadius: Theme.Radius.control + 3, style: .continuous)
                    .strokeBorder(Theme.accent.opacity(0.28), lineWidth: 3)
                    .padding(-3)
                    .allowsHitTesting(false)
            }
        }
        .onHover { hovering = $0 }
        .softAnimation(Theme.Motion.focus, value: focused)
    }
}

/// 36x22 switch with an 18 px knob, centered vertically in the track.
struct SoftSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            configuration.label
            SwitchTrack(isOn: configuration.isOn) { configuration.isOn.toggle() }
        }
    }
}

private struct SwitchTrack: View {
    let isOn: Bool
    let toggle: () -> Void
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule().fill(isOn ? Theme.accent : Theme.trackOff)
            Capsule().fill(LinearGradient(colors: [Theme.inset.opacity(0.6), .clear], startPoint: .top,
                                          endPoint: UnitPoint(x: 0.5, y: 0.3)))
            Circle()
                .fill(Theme.knob)
                .frame(width: 18, height: 18)
                .shadow(color: Theme.shadow, radius: 1, y: 1)
                .padding(2)
        }
        .frame(width: 36, height: 22)
        .overlay {
            if isFocused {
                Capsule().strokeBorder(Theme.accent, lineWidth: 2).padding(-4)
            }
        }
        .opacity(isEnabled ? 1 : 0.45)
        .contentShape(Capsule())
        .onTapGesture { if isEnabled { toggle() } }
        .softAnimation(Theme.Motion.toggle, value: isOn)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.space) { if isEnabled { toggle() }; return .handled }
    }
}

extension ToggleStyle where Self == SoftSwitchStyle {
    static var soft: SoftSwitchStyle { SoftSwitchStyle() }
}

/// Select: button-styled menu with a 12 px chevron, label and chevron centered vertically.
struct SoftMenu<Value: Hashable>: View {
    let options: [(label: String, value: Value)]
    @Binding var selection: Value
    var width: CGFloat?

    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
        Menu {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                Button {
                    selection = option.value
                } label: {
                    if option.value == selection {
                        Label(option.label, systemImage: "checkmark")
                    } else {
                        Text(option.label)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(options.first { $0.value == selection }?.label ?? "")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.fg)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.leading, 12)
            .padding(.trailing, 10)
            .frame(width: width, height: Theme.Size.button)
            .background(hovering ? Theme.controlHover : Theme.control, in: shape)
            .overlay(shape.strokeBorder(Theme.border, lineWidth: 1))
            .overlay(shape.inset(by: 1).strokeBorder(
                LinearGradient(colors: [Theme.highlight, .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.3)),
                lineWidth: 1))
            .shadow(color: Theme.shadow, radius: 1, y: 1)
            .contentShape(shape)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .focusEffectDisabled()
        .onHover { hovering = $0 }
        .opacity(isEnabled ? 1 : 0.45)
    }
}

// MARK: - Badges and small elements

struct Badge: View {
    let text: String
    var tone: Tone = .muted

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(tone.color)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .frame(height: Theme.Size.badge)
            .background(Capsule().fill(tone.color.opacity(0.14)))
            .overlay(Capsule().strokeBorder(tone.color.opacity(0.32), lineWidth: 1))
            .fixedSize()
    }
}

struct CountBead: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.onDanger)
            .frame(width: Theme.Size.bead, height: Theme.Size.bead)
            .background(Circle().fill(Theme.dangerFill))
    }
}

struct SectionCaps: View {
    let text: String
    var tone: Tone = .muted

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.66)
            .foregroundStyle(tone.color)
    }
}

struct StatusDot: View {
    let tone: Tone
    var body: some View { Circle().fill(tone.color).frame(width: 6, height: 6) }
}

/// Wraps its children onto new lines when they do not fit (used for badge rows).
struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(width: bounds.width, subviews: subviews)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                                  proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (CGSize(width: maxX, height: y + lineHeight), origins)
    }
}

// MARK: - EmptyState (shared pattern)

struct EmptyAction: Identifiable {
    let id = UUID()
    let title: String
    var primary = false
    let action: () -> Void
}

/// One vertical axis, centered: 72 px orb with a tone icon, 18/24 title, 13/18 muted body (max 300),
/// 32 px actions. Centered in whatever space it is given.
struct EmptyStateView: View {
    enum Icon { case check, search, cursor, record, scan, lock, warning }

    let icon: Icon
    let tone: Tone
    let title: String
    let message: String
    var actions: [EmptyAction] = []

    var body: some View {
        VStack(spacing: 12) {
            EmptyOrb(icon: icon, tone: tone)
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.fg)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: 300)
                .fixedSize(horizontal: false, vertical: true)
            if !actions.isEmpty {
                HStack(spacing: 10) {
                    ForEach(actions) { item in
                        Button(item.title, action: item.action).softButton(item.primary ? .primary : .secondary)
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}

private struct EmptyOrb: View {
    let icon: EmptyStateView.Icon
    let tone: Tone
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spin = false

    var body: some View {
        ZStack {
            Circle().fill(tone.color.opacity(0.12))
            Circle().strokeBorder(tone.color.opacity(0.35), lineWidth: 1)
            glyph.foregroundStyle(tone.color)
        }
        .frame(width: Theme.Size.orb, height: Theme.Size.orb)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var glyph: some View {
        switch icon {
        case .scan:
            Circle().trim(from: 0, to: 0.75)
                .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 24, height: 24)
                .rotationEffect(.degrees(spin ? 360 : 0))
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { spin = true }
                }
        case .warning:
            // Optical centering: the triangle's visual mass sits low, so it is nudged +1 px.
            Image(systemName: "exclamationmark.triangle").font(.system(size: 26, weight: .regular)).offset(y: -1)
        default:
            Image(systemName: symbol).font(.system(size: 26, weight: .regular))
        }
    }

    private var symbol: String {
        switch icon {
        case .check: return "checkmark"
        case .search: return "magnifyingglass"
        case .cursor: return "cursorarrow"
        case .record: return "record.circle"
        case .lock: return "lock.open"
        case .scan, .warning: return ""
        }
    }
}
