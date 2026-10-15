// swift-tools-version: 6.0
import PackageDescription

/// IsoKit renders the building and unit sprites offline (capability `iso-art-kit`).
/// It is a tool: no app target links it. SceneKit types are not Sendable, so the
/// package stays in the Swift 5 language mode.
let package = Package(
    name: "IsoKit",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "isokit", targets: ["isokit"])
    ],
    targets: [
        .target(
            name: "IsoKitCore",
            path: "Sources/IsoKitCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "isokit",
            dependencies: ["IsoKitCore"],
            path: "Sources/isokit",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "IsoKitCoreTests",
            dependencies: ["IsoKitCore"],
            path: "Tests/IsoKitCoreTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
