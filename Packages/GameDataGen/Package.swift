// swift-tools-version: 6.0
import PackageDescription

// Build-time tool: compiles the YAML content packs under
// Packages/CityCore/GameData into Swift. CityCore never depends on it.

let package = Package(
    name: "GameDataGen",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "GameDataModel", targets: ["GameDataModel"]),
        .executable(name: "gamedata-gen", targets: ["gamedata-gen"])
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", exact: "6.2.2")
    ],
    targets: [
        .target(
            name: "GameDataModel",
            dependencies: ["Yams"],
            path: "Sources/GameDataModel"
        ),
        .executableTarget(
            name: "gamedata-gen",
            dependencies: ["GameDataModel"],
            path: "Sources/gamedata-gen"
        ),
        .testTarget(
            name: "GameDataGenTests",
            dependencies: ["GameDataModel"],
            path: "Tests/GameDataGenTests"
        )
    ]
)
