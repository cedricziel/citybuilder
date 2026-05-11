// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CityRender2D",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "CityRender2D", targets: ["CityRender2D"])
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
        .testTarget(
            name: "CityRender2DTests",
            dependencies: ["CityRender2D"],
            path: "Tests/CityRender2DTests"
        )
    ]
)
