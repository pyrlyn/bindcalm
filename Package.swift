// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Bindcalm",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Bindcalm", targets: ["Bindcalm"]),
    ],
    targets: [
        .target(
            name: "BindcalmCore",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ApplicationServices"),
            ]
        ),
        .executableTarget(
            name: "Bindcalm",
            dependencies: ["BindcalmCore"]
        ),
        .testTarget(
            name: "BindcalmCoreTests",
            dependencies: ["BindcalmCore"]
        ),
    ],
    // Swift 5 language mode: the AX/Carbon/CGEvent C APIs are not annotated for strict concurrency yet.
    swiftLanguageModes: [.v5]
)
