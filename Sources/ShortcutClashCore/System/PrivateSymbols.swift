import Darwin
import Foundation

public struct SymbolProbeResult: Codable, Sendable, Hashable {
    public var name: String
    public var found: Bool
    public var image: String?
    public var note: String
}

/// Runtime lookup of undocumented symbols. Nothing here links against private frameworks,
/// so a symbol disappearing in a future macOS only disables a feature instead of breaking launch.
public enum PrivateSymbols {
    static let imagePaths = [
        "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
        "/System/Library/Frameworks/Carbon.framework/Frameworks/HIToolbox.framework/HIToolbox",
        "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics",
    ]

    public static let candidates: [(String, String)] = [
        ("GetEventHotKeyCount", "Carbon: count of registered hotkeys (never public)"),
        ("GetEventHotKeyInfo", "Carbon: info about a registered hotkey (never public)"),
        ("CopySymbolicHotKeys", "HIToolbox: copy of the symbolic hotkey table"),
        ("CGSGetSymbolicHotKeyValue", "SkyLight: effective value of a symbolic hotkey"),
        ("CGSIsSymbolicHotKeyEnabled", "SkyLight: whether a symbolic hotkey is enabled"),
        ("CGSSetSymbolicHotKeyEnabled", "SkyLight: write access (never called by this app)"),
        ("SLSGetSymbolicHotKeyValue", "SkyLight SLS-prefixed alias"),
        ("SLSIsSymbolicHotKeyEnabled", "SkyLight SLS-prefixed alias"),
        ("_CGSDefaultConnection", "SkyLight: default WindowServer connection"),
        ("CGSMainConnectionID", "SkyLight: main WindowServer connection"),
        ("CGSGetGlobalHotKeyOperatingMode", "SkyLight: global hotkey operating mode (read)"),
        ("CGSSetGlobalHotKeyOperatingMode", "SkyLight: disables all global hotkeys (never called)"),
        ("IsSecureEventInputEnabled", "Carbon, public: secure input state"),
        ("RegisterEventHotKey", "Carbon, public: hotkey registration (probe method)"),
    ]

    private static let handles: [UnsafeMutableRawPointer] = imagePaths.compactMap { dlopen($0, RTLD_LAZY | RTLD_NOLOAD) ?? dlopen($0, RTLD_LAZY) }

    public static func lookup(_ name: String) -> UnsafeMutableRawPointer? {
        if let ptr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) { return ptr } // RTLD_DEFAULT
        for handle in handles {
            if let ptr = dlsym(handle, name) { return ptr }
        }
        return nil
    }

    public static func probeAll() -> [SymbolProbeResult] {
        candidates.map { name, note in
            guard let ptr = lookup(name) else { return SymbolProbeResult(name: name, found: false, image: nil, note: note) }
            var info = Dl_info()
            var image: String?
            if dladdr(ptr, &info) != 0, let fname = info.dli_fname {
                image = (String(cString: fname) as NSString).lastPathComponent
            }
            return SymbolProbeResult(name: name, found: true, image: image, note: note)
        }
    }
}
