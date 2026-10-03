import AppKit

/// Resolves bundle IDs to display names and paths via LaunchServices, with a cache.
public final class OwnerResolver: @unchecked Sendable {
    private let lock = NSLock()
    private var cache: [String: HotKeyOwner] = [:]

    public init() {}

    public func owner(bundleID: String) -> HotKeyOwner {
        lock.lock()
        if let cached = cache[bundleID] { lock.unlock(); return cached }
        lock.unlock()

        var owner = HotKeyOwner(name: bundleID, bundleID: bundleID)
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            owner = Self.owner(appURL: url, bundleID: bundleID)
        }
        lock.lock()
        cache[bundleID] = owner
        lock.unlock()
        return owner
    }

    public func owner(for app: NSRunningApplication) -> HotKeyOwner {
        if let id = app.bundleIdentifier {
            var resolved = owner(bundleID: id)
            if resolved.path == nil { resolved.path = app.bundleURL?.path }
            if resolved.name == id, let name = app.localizedName { resolved.name = name }
            return resolved
        }
        return HotKeyOwner(name: app.localizedName ?? "pid \(app.processIdentifier)", bundleID: nil,
                           path: app.bundleURL?.path ?? app.executableURL?.path)
    }

    public static func owner(appURL url: URL, bundleID: String? = nil) -> HotKeyOwner {
        let bundle = Bundle(url: url)
        let name = (bundle?.localizedInfoDictionary?["CFBundleDisplayName"] as? String)
            ?? (bundle?.infoDictionary?["CFBundleDisplayName"] as? String)
            ?? (bundle?.infoDictionary?["CFBundleName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent
        return HotKeyOwner(name: name, bundleID: bundleID ?? bundle?.bundleIdentifier, path: url.path)
    }
}
