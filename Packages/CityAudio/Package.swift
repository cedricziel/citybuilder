// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CityAudio",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "CityAudio", targets: ["CityAudio"])
    ],
    dependencies: [
        .package(path: "../CityCore"),
        .package(path: "../CityPersistence"),
        .package(path: "../CityUI")
    ],
    targets: [
        .target(
            name: "CityAudio",
            dependencies: ["CityCore", "CityPersistence", "CityUI"],
            path: "Sources/CityAudio"
        ),
        .testTarget(
            name: "CityAudioTests",
            dependencies: ["CityAudio", "CityCore", "CityPersistence"],
            path: "Tests/CityAudioTests"
        )
    ]
)
