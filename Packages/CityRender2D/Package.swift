// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CityRender2D",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "CityRender2D", targets: ["CityRender2D"]),
        .executable(name: "sprite-content-gate", targets: ["SpriteContentGateCLI"])
    ],
    dependencies: [
        .package(path: "../CityCore")
    ],
    targets: [
        .target(
            name: "CityRender2D",
            dependencies: ["CityCore"],
            path: "Sources/CityRender2D"
        ),
        .target(
            name: "SpriteContentGate",
            path: "Sources/SpriteContentGate"
        ),
        .executableTarget(
            name: "SpriteContentGateCLI",
            dependencies: ["SpriteContentGate"],
            path: "Sources/SpriteContentGateCLI"
        ),
        .testTarget(
            name: "CityRender2DTests",
            dependencies: ["CityRender2D"],
            path: "Tests/CityRender2DTests"
        ),
        .testTarget(
            name: "SpriteContentGateTests",
            dependencies: ["SpriteContentGate"],
            path: "Tests/SpriteContentGateTests"
        )
    ]
)
