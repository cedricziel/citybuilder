// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CityRender3D",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "CityRender3D", targets: ["CityRender3D"])
    ],
    dependencies: [
        .package(path: "../CityCore")
    ],
    targets: [
        .target(
            name: "CityRender3D",
            dependencies: ["CityCore"],
            path: "Sources/CityRender3D"
        ),
        .testTarget(
            name: "CityRender3DTests",
            dependencies: ["CityRender3D"],
            path: "Tests/CityRender3DTests"
        )
    ]
)
