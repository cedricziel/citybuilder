import CityCore
import Foundation
import SceneKit

/// 3D building-portrait subsystem (spec building-portraits-3d).
public enum CityRender3D {
    public static let version = "0.0.0"
}

/// USDZ asset catalog. Maps a BuildingKind to an asset path bundled with
/// the app. nil means "no 3D portrait for this kind" — the inspector
/// hides the affordance.
public enum PortraitAssetCatalog {
    private static let assets: [BuildingKind: String] = [
        .townCenter: "town_center.usdz"
    ]

    public static func assetPath(for kind: BuildingKind) -> String? {
        assets[kind]
    }

    public static func hasAsset(for kind: BuildingKind) -> Bool {
        assets[kind] != nil
    }
}

/// View-model for the 3D portrait overlay. Headless-testable.
public struct PortraitViewModel: Equatable, Sendable {
    public let kind: BuildingKind
    public let assetPath: String?
    public private(set) var rotationDegrees: Double
    public let openedAtTick: UInt64

    public init(kind: BuildingKind, openedAtTick: UInt64) {
        self.kind = kind
        self.assetPath = PortraitAssetCatalog.assetPath(for: kind)
        self.rotationDegrees = 0
        self.openedAtTick = openedAtTick
    }

    public mutating func rotate(by degrees: Double) {
        rotationDegrees = (rotationDegrees + degrees).truncatingRemainder(dividingBy: 360)
        if rotationDegrees < 0 { rotationDegrees += 360 }
    }

    public var isAvailable: Bool {
        assetPath != nil
    }
}
