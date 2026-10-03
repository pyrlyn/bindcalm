// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ShortcutClash",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ShortcutClash", targets: ["ShortcutClash"]),
    ],
    targets: [
        .target(
            name: "ShortcutClashCore",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ApplicationServices"),
            ]
        ),
        .executableTarget(
            name: "ShortcutClash",
            dependencies: ["ShortcutClashCore"]
        ),
        .testTarget(
            name: "ShortcutClashCoreTests",
            dependencies: ["ShortcutClashCore"]
        ),
    ],
    // Swift 5 language mode: the AX/Carbon/CGEvent C APIs are not annotated for strict concurrency yet.
    swiftLanguageModes: [.v5]
)
