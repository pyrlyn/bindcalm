import Foundation

/// Services menu shortcuts: defaults from `NSServices` in bundles (apps, .service, Automator/Shortcuts
/// .workflow quick actions) overridden by the user's choices in the `pbs` domain (`NSServicesStatus`).
public struct ServicesStrategy: HotKeyDiscoveryStrategy {
    public init() {}
    public var id: DiscoveryMethod { .services }
    public var displayName: String { "Services (NSServices + pbs)" }
    public var summary: String { "Shortcuts of the Services menu. A pbs entry (NSServicesStatus) says whether a service is enabled. A default shortcut from Info.plist without such an entry is shown as disabled: macOS does not report its real state." }

    static let quickActionOwner = HotKeyOwner(name: "Quick Actions (Automator/Shortcuts)", bundleID: nil)

    public func discover(in context: DiscoveryContext) async throws -> [DiscoveredHotKey] {
        var found: [DiscoveredHotKey] = []
        let statusDict = CFPreferencesCopyValue("NSServicesStatus" as CFString, "pbs" as CFString,
                                                kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String: Any] ?? [:]
        let status = ServicesParser.parseStatus(statusDict, layouts: context.layouts)
        var statusByKey: [String: ServiceStatusEntry] = [:]
        for entry in status {
            statusByKey[Self.key(entry.providerBundleID, entry.title)] = entry
            guard let combo = entry.combo else { continue }
            let owner = entry.providerBundleID.map { context.owners.owner(bundleID: $0) } ?? Self.quickActionOwner
            found.append(DiscoveredHotKey(combo: combo, owner: owner, method: id, confidence: .reliable, scope: .global,
                                          action: "Service: \(entry.title)", enabled: entry.enabled,
                                          source: "pbs → NSServicesStatus[\"\(entry.rawKey)\"]"))
        }

        var roots = InstalledApps.roots(home: context.home)
        roots += ["/System/Library/Services", "/Library/Services"].map { URL(fileURLWithPath: $0) }
        roots.append(context.home.appendingPathComponent("Library/Services"))
        for bundle in InstalledApps.bundles(in: roots, extensions: ["app", "service", "workflow"]) {
            guard let info = InstalledApps.infoPlist(of: bundle),
                  let services = info["NSServices"] as? [[String: Any]] else { continue }
            let bundleID = info["CFBundleIdentifier"] as? String
            let isWorkflow = bundle.pathExtension == "workflow"
            for shortcut in ServicesParser.parseInfoPlistServices(services) {
                let match = statusByKey[Self.key(bundleID, shortcut.title)]
                guard let resolved = ServicesParser.resolveDefault(shortcut, status: match) else { continue }
                var owner = isWorkflow ? Self.quickActionOwner : OwnerResolver.owner(appURL: bundle, bundleID: bundleID)
                if isWorkflow { owner.path = bundle.path }
                let plistSource = "\(bundle.path)/Contents/Info.plist → NSServices → NSKeyEquivalent = \"\(shortcut.character)\""
                let source = resolved.confirmed
                    ? "\(plistSource) · \(match?.rawKey ?? "pbs")"
                    : "\(plistSource) · default not confirmed in NSServicesStatus"
                found.append(DiscoveredHotKey(combo: resolved.combo, owner: owner, method: id,
                                              confidence: resolved.confirmed ? .reliable : .partial, scope: .global,
                                              action: "Service: \(shortcut.title)", enabled: resolved.enabled,
                                              source: source, definingCharacter: resolved.definingCharacter))
            }
        }
        return found
    }

    static func key(_ bundleID: String?, _ title: String) -> String {
        "\(bundleID?.lowercased() ?? "-")|\(title)"
    }
}
