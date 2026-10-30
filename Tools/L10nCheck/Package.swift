// swift-tools-version: 6.0
import PackageDescription

/// L10nCheck guards the String Catalogs (capability `localization`, design D8 of
/// `add-localization`). It is a tool: no app target links it.
let package = Package(
    name: "L10nCheck",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "l10n-check", targets: ["l10n-check"])
    ],
    targets: [
        .target(name: "L10nCheckCore", path: "Sources/L10nCheckCore"),
        .executableTarget(name: "l10n-check", dependencies: ["L10nCheckCore"], path: "Sources/l10n-check"),
        .testTarget(name: "L10nCheckCoreTests", dependencies: ["L10nCheckCore"], path: "Tests/L10nCheckCoreTests")
    ]
)
