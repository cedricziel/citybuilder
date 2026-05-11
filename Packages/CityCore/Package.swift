// swift-tools-version: 6.0
import PackageDescription

// IMPORTANT (design D1, D13): CityCore is the framework-free simulation core.
// It MUST NOT import any Apple UI framework (UIKit, AppKit, SwiftUI,
// SpriteKit, SceneKit, RealityKit). Only Foundation and Swift are permitted.
// This package compiles on Linux as a consequence — and so do its tests.

let package = Package(
    name: "CityCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "CityCore", targets: ["CityCore"])
    ],
    targets: [
        .target(
            name: "CityCore",
            path: "Sources/CityCore"
        ),
        .testTarget(
            name: "CityCoreTests",
            dependencies: ["CityCore"],
            path: "Tests/CityCoreTests"
        )
    ]
)
