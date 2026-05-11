// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CityUI",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "CityUI", targets: ["CityUI"])
    ],
    dependencies: [
        .package(path: "../CityCore")
    ],
    targets: [
        .target(
            name: "CityUI",
            dependencies: ["CityCore"],
            path: "Sources/CityUI"
        ),
        .testTarget(
            name: "CityUITests",
            dependencies: ["CityUI"],
            path: "Tests/CityUITests"
        )
    ]
)
