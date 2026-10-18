// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Bindcalm",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Bindcalm", targets: ["Bindcalm"]),
        // Linked by the Xcode app target of the release build (xcode/project.yml).
        .library(name: "BindcalmCore", targets: ["BindcalmCore"]),
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
