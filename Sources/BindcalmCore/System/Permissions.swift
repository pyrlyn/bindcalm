import AppKit
import ApplicationServices
import Carbon
import CoreGraphics

public enum PermissionKind: String, Codable, Sendable {
    case accessibility
    case inputMonitoring
}

public struct PermissionSnapshot: Codable, Sendable, Equatable {
    public var accessibility: Bool
    public var inputMonitoring: Bool
    public var secureInput: Bool
}

/// TCC checks. Preflight calls never show a prompt; only the explicit `request*` calls do.
public enum Permissions {
    public static var accessibilityGranted: Bool { AXIsProcessTrusted() }

    /// Shows the system Accessibility prompt (once per app identity; later calls only re-check).
    @discardableResult
    public static func requestAccessibility() -> Bool {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    public static var inputMonitoringGranted: Bool { CGPreflightListenEventAccess() }

    @discardableResult
    public static func requestInputMonitoring() -> Bool { CGRequestListenEventAccess() }

    /// While a password field (or Terminal "Secure Keyboard Entry") holds secure input, event taps and
    /// global monitors receive nothing — live capture results are meaningless then.
    public static var secureInputEnabled: Bool { IsSecureEventInputEnabled() }

    public static func snapshot() -> PermissionSnapshot {
        PermissionSnapshot(accessibility: accessibilityGranted, inputMonitoring: inputMonitoringGranted,
                           secureInput: secureInputEnabled)
    }

    public static func openSettings(for kind: PermissionKind) {
        let anchor = kind == .accessibility ? "Privacy_Accessibility" : "Privacy_ListenEvent"
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }
}
