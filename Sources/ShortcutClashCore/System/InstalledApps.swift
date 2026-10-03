import Foundation

/// Enumerates application bundles in the standard locations (two levels deep, e.g. /Applications/Utilities).
public enum InstalledApps {
    public static func roots(home: URL) -> [URL] {
        [URL(fileURLWithPath: "/Applications"), home.appendingPathComponent("Applications"),
         URL(fileURLWithPath: "/System/Applications")]
    }

    public static func bundles(in roots: [URL], extensions: Set<String> = ["app"], depth: Int = 2) -> [URL] {
        var result: [URL] = []
        let fm = FileManager.default
        func visit(_ dir: URL, level: Int) {
            guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey],
                                                          options: [.skipsHiddenFiles]) else { return }
            for item in items {
                if extensions.contains(item.pathExtension) {
                    result.append(item)
                } else if level < depth, (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
                          item.pathExtension.isEmpty {
                    visit(item, level: level + 1)
                }
            }
        }
        roots.forEach { visit($0, level: 1) }
        return result
    }

    public static func infoPlist(of bundle: URL) -> [String: Any]? {
        let url = bundle.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    }

    /// Bundle IDs that have a preferences domain on disk, plus installed apps.
    public static func knownBundleIDs(home: URL) -> Set<String> {
        var ids = Set<String>()
        let prefs = home.appendingPathComponent("Library/Preferences")
        if let files = try? FileManager.default.contentsOfDirectory(atPath: prefs.path) {
            for file in files where file.hasSuffix(".plist") {
                ids.insert(String(file.dropLast(6)))
            }
        }
        for app in bundles(in: roots(home: home)) {
            if let id = Bundle(url: app)?.bundleIdentifier { ids.insert(id) }
        }
        return ids
    }
}
