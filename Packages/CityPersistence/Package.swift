// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CityPersistence",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "CityPersistence", targets: ["CityPersistence"])
    ],
    dependencies: [
        .package(path: "../CityCore")
    ],
    targets: [
        .target(
            name: "CityPersistence",
            dependencies: ["CityCore"],
            path: "Sources/CityPersistence"
        ),
        .testTarget(
            name: "CityPersistenceTests",
            dependencies: ["CityPersistence"],
            path: "Tests/CityPersistenceTests"
        )
    ]
)
