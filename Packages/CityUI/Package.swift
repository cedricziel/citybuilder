// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CityUI",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .tvOS(.v18)
    ],
    products: [
        .library(name: "CityUI", targets: ["CityUI"])
    ],
    dependencies: [
        .package(path: "../CityCore"),
        .package(path: "../CityRender2D")
    ],
    targets: [
        .target(
            name: "CityUI",
            dependencies: ["CityCore", "CityRender2D"],
            path: "Sources/CityUI",
            resources: [.copy("Resources/Localizable.xcstrings"), .copy("Resources/GameData.xcstrings")]
        ),
        .testTarget(
            name: "CityUITests",
            dependencies: ["CityUI", "CityCore"],
            path: "Tests/CityUITests"
        )
    ]
)
