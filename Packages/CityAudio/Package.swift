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
        .package(path: "../CityCore")
    ],
    targets: [
        .target(
            name: "CityAudio",
            dependencies: ["CityCore"],
            path: "Sources/CityAudio"
        ),
        .testTarget(
            name: "CityAudioTests",
            dependencies: ["CityAudio", "CityCore"],
            path: "Tests/CityAudioTests"
        )
    ]
)
