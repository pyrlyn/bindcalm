import AppKit
import ApplicationServices
import CoreGraphics

public struct LiveObservation: Identifiable, Hashable, Codable, Sendable {
    public var id = UUID()
    public var combo: KeyCombo
    public var time: Date
    public var frontmost: HotKeyOwner?
    public var axFocusedApp: String?
    public var ourAppActive: Bool
    public var seenByTap = false
    public var seenByGlobalMonitor = false
    public var seenByLocalMonitor = false

    public enum Verdict: String, Codable, Sendable {
        case swallowed
        case deliveredToUs
        case deliveredToFrontmost
        case unknown
    }

    /// Interpretation of which taps saw the press. Carbon hotkeys and symbolic hotkeys are matched
    /// after session event taps but before delivery to apps, so "tap only" suggests a global consumer.
    public var verdict: Verdict {
        if seenByLocalMonitor { return .deliveredToUs }
        if seenByGlobalMonitor { return .deliveredToFrontmost }
        if seenByTap { return .swallowed }
        return .unknown
    }

    public var verdictText: String {
        switch verdict {
        case .swallowed: return "Не дошло до приложений — вероятно, перехвачено глобальным сочетанием"
        case .deliveredToUs: return "Дошло до этого окна — глобального перехватчика нет"
        case .deliveredToFrontmost: return "Доставлено активному приложению"
        case .unknown: return "Недостаточно данных (нет разрешений?)"
        }
    }
}

/// Thread-safe hand-off of observations to the live strategies, which run off the main actor.
public final class LiveObservationStore: @unchecked Sendable {
    public static let shared = LiveObservationStore()
    private let lock = NSLock()
    private var items: [LiveObservation] = []

    public func replace(_ observations: [LiveObservation]) {
        lock.lock(); items = observations; lock.unlock()
    }

    public func snapshot() -> [LiveObservation] {
        lock.lock(); defer { lock.unlock() }
        return items
    }
}

/// Record mode. Only shortcut-like presses (⌘/⌃/⌥ or F-keys) are kept, so ordinary typing is never logged.
@MainActor
public final class LiveCaptureController: ObservableObject {
    @Published public private(set) var isRunning = false
    @Published public private(set) var observations: [LiveObservation] = []
    @Published public private(set) var tapActive = false
    @Published public private(set) var monitorsActive = false
    @Published public private(set) var lastMessage: String?

    public var useEventTap = true
    public var useMonitors = true

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var tap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private let owners = OwnerResolver()
    static let correlationWindow: TimeInterval = 0.35
    static let maxObservations = 200

    public init() {}

    public func start() {
        guard !isRunning else { return }
        var notes: [String] = []
        if useMonitors {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                MainActor.assumeIsolated { self?.record(event: event, source: .global) }
            }
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                MainActor.assumeIsolated { self?.record(event: event, source: .local) }
                return event
            }
            monitorsActive = true
            if !AXIsProcessTrusted() {
                notes.append("Глобальный монитор NSEvent ничего не получит без «Универсального доступа».")
            }
        }
        if useEventTap {
            if startTap() {
                tapActive = true
            } else {
                notes.append("CGEvent tap не создан: нужно разрешение «Мониторинг ввода».")
            }
        }
        if Permissions.secureInputEnabled {
            notes.append("Включён защищённый ввод (Secure Input): нажатия не видны никаким перехватчикам.")
        }
        isRunning = true
        lastMessage = notes.isEmpty ? nil : notes.joined(separator: " ")
    }

    public func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let tapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), tapSource, .commonModes) }
        tap = nil
        tapSource = nil
        tapActive = false
        monitorsActive = false
        isRunning = false
    }

    public func clear() {
        observations.removeAll()
        LiveObservationStore.shared.replace([])
    }

    enum Source { case tap, global, local }

    private func startTap() -> Bool {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let controller = Unmanaged<LiveCaptureController>.fromOpaque(refcon).takeUnretainedValue()
            MainActor.assumeIsolated {
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = controller.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                } else if type == .keyDown {
                    let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
                    controller.record(keyCode: code, flags: event.flags.rawValue, source: .tap)
                }
            }
            return Unmanaged.passUnretained(event)
        }
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
                                           eventsOfInterest: mask, callback: callback, userInfo: refcon) else { return false }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        tap = port
        tapSource = source
        return true
    }

    private func record(event: NSEvent, source: Source) {
        record(keyCode: event.keyCode, flags: UInt64(event.modifierFlags.rawValue), source: source)
    }

    private func record(keyCode: UInt16, flags: UInt64, source: Source) {
        guard isRunning, !KeyCodes.modifierKeyCodes.contains(keyCode) else { return }
        let combo = KeyCombo(keyCode: keyCode, modifiers: ModifierSet(cocoa: flags))
        guard combo.modifiers.isShortcutLike || KeyCodes.isFunctionKey(keyCode) else { return }
        let now = Date()
        let index = observations.firstIndex {
            $0.combo == combo && now.timeIntervalSince($0.time) < Self.correlationWindow && !$0.seen(by: source)
        }
        var observation: LiveObservation
        if let index {
            observation = observations[index]
        } else {
            let front = NSWorkspace.shared.frontmostApplication
            var axName: String?
            if let pid = AccessibilityMenuStrategy.focusedApplicationPID() {
                axName = NSRunningApplication(processIdentifier: pid)?.localizedName
            }
            observation = LiveObservation(combo: combo, time: now, frontmost: front.map { owners.owner(for: $0) },
                                          axFocusedApp: axName, ourAppActive: NSApp?.isActive ?? false)
        }
        switch source {
        case .tap: observation.seenByTap = true
        case .global: observation.seenByGlobalMonitor = true
        case .local: observation.seenByLocalMonitor = true
        }
        if let index {
            observations[index] = observation
        } else {
            observations.insert(observation, at: 0)
            if observations.count > Self.maxObservations { observations.removeLast() }
        }
        LiveObservationStore.shared.replace(observations)
    }
}

extension LiveObservation {
    func seen(by source: LiveCaptureController.Source) -> Bool {
        switch source {
        case .tap: return seenByTap
        case .global: return seenByGlobalMonitor
        case .local: return seenByLocalMonitor
        }
    }
}

/// Exposes recorded presses as findings so they appear next to registry data in the same groups.
public struct NSEventMonitorStrategy: HotKeyDiscoveryStrategy {
    public init() {}
    public var id: DiscoveryMethod { .nsEventMonitor }
    public var displayName: String { "Живой захват: NSEvent мониторы" }
    public var summary: String { "Глобальный и локальный мониторы NSEvent в режиме записи. Глобальный требует «Универсальный доступ». Только наблюдение, эвристика." }
    public var isLiveCapture: Bool { true }

    public func discover(in context: DiscoveryContext) async throws -> [DiscoveredHotKey] {
        LiveObservationStore.shared.snapshot().filter { $0.seenByGlobalMonitor || $0.seenByLocalMonitor }.map {
            DiscoveredHotKey(combo: $0.combo, owner: $0.frontmost ?? .unknown, method: id, confidence: .heuristic,
                             scope: .observed, action: $0.verdictText,
                             source: "NSEvent \($0.seenByLocalMonitor ? "local" : "global") monitor, \($0.time.formatted(date: .omitted, time: .standard))")
        }
    }
}

public struct CGEventTapStrategy: HotKeyDiscoveryStrategy {
    public init() {}
    public var id: DiscoveryMethod { .cgEventTap }
    public var displayName: String { "Живой захват: CGEvent tap" }
    public var summary: String { "Прослушивающий CGEvent tap на уровне сессии в режиме записи. Требует «Мониторинг ввода». Видит нажатие до глобальных сочетаний; эвристика." }
    public var requiredPermission: PermissionKind? { .inputMonitoring }
    public var isLiveCapture: Bool { true }

    public func discover(in context: DiscoveryContext) async throws -> [DiscoveredHotKey] {
        LiveObservationStore.shared.snapshot().filter { $0.seenByTap }.map {
            DiscoveredHotKey(combo: $0.combo, owner: $0.frontmost ?? .unknown, method: id, confidence: .heuristic,
                             scope: .observed, action: $0.verdictText,
                             source: "CGEvent tap (session), \($0.time.formatted(date: .omitted, time: .standard))")
        }
    }
}
