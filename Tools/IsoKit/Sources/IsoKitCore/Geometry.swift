// World axes: x = +col (screen down-right), z = +row (screen down-left), y = up.
// One tile = 4 m. A footprint of n x n tiles spans x, z in [0, 4n].
import Foundation
import SceneKit

extension SCNVector3 {
    static func + (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        SCNVector3(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }

    static func - (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        SCNVector3(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
    }

    static func * (lhs: SCNVector3, rhs: CGFloat) -> SCNVector3 {
        SCNVector3(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs)
    }

    func dot(_ other: SCNVector3) -> CGFloat {
        x * other.x + y * other.y + z * other.z
    }

    func cross(_ other: SCNVector3) -> SCNVector3 {
        SCNVector3(y * other.z - z * other.y, z * other.x - x * other.z, x * other.y - y * other.x)
    }

    var length: CGFloat {
        dot(self).squareRoot()
    }

    var normalized: SCNVector3 {
        self * (1 / max(length, 1e-9))
    }
}

/// 2:1 dimetric projection. Yaw 45 deg puts the tile diagonal horizontal; pitch -30 deg
/// (sin 30 = 1/2) squashes it 2:1. A 4 m tile edge projects to 4*sqrt(2) view units = 64 pt.
public enum Iso {
    public static let tileMetres: CGFloat = 4
    public static let pxPerMetre: CGFloat = 64 / (CGFloat(2).squareRoot() * tileMetres)
    static let cos30: CGFloat = .init(3).squareRoot() / 2
    static let invRoot2: CGFloat = 1 / CGFloat(2).squareRoot()
    static let forward = SCNVector3(-cos30 * invRoot2, -0.5, -cos30 * invRoot2)
    static let up = SCNVector3(-0.5 * invRoot2, cos30, -0.5 * invRoot2)
}

/// One atlas cell: n x n footprint, 64n points wide, `heightPx` points tall.
/// The footprint's bottom vertex sits at the cell's bottom-centre (SpriteKit anchor (0.5, 0)).
public struct SpriteCell: Equatable {
    public let footprint: Int
    public let heightPx: Int

    public init(footprint: Int, heightPx: Int) {
        self.footprint = footprint
        self.heightPx = heightPx
    }

    public var widthPx: Int {
        64 * footprint
    }

    public var sizeMetres: CGFloat {
        CGFloat(footprint) * Iso.tileMetres
    }
}
