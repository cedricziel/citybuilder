import CityCore
import CoreGraphics
import Foundation

/// An opaque-or-clear 8-bit colour.
public struct MinimapRGBA: Hashable, Sendable {
    public let red, green, blue, alpha: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8 = 255) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// A colour from "#RRGGBB".
    public init(hex: String) {
        let value = UInt32(hex.dropFirst(), radix: 16) ?? 0
        self.init(red: UInt8((value >> 16) & 0xFF), green: UInt8((value >> 8) & 0xFF), blue: UInt8(value & 0xFF))
    }

    public static let clear = MinimapRGBA(red: 0, green: 0, blue: 0, alpha: 0)
}

/// The minimap's colours. Spec: `platform-shells` / Minimap.
public enum MinimapPalette {
    private static let water = MinimapRGBA(hex: "#3B78B0")
    private static let beach = MinimapRGBA(hex: "#E6D08A")
    private static let grass = MinimapRGBA(hex: "#7DB35A")
    private static let forest = MinimapRGBA(hex: "#2E6631")
    private static let rock = MinimapRGBA(hex: "#8A8478")
    public static let player = MinimapRGBA(hex: RivalColour.playerHex)

    public static func colour(for terrain: TerrainType) -> MinimapRGBA {
        switch terrain {
        case .water: water
        case .beach: beach
        case .grass: grass
        case .forest: forest
        case .mountain: rock
        }
    }

    /// A rival the snapshot does not know, which should not happen.
    static let unknownOwner = MinimapRGBA(hex: "#8E8E93")

    public static func colour(for owner: Owner, in snapshot: WorldSnapshot) -> MinimapRGBA {
        guard let rivalID = owner.rivalID else { return player }
        return snapshot.rival(rivalID).map { MinimapRGBA(hex: $0.colour.hex) } ?? unknownOwner
    }
}

/// The terrain drawn as pixels, 2 per unit of `u` across and 1 per unit of
/// `v` down, so the image is `2(W + H)` by `W + H` pixels, capped at
/// `maxWidth` pixels across, about the largest the minimap shows. Pixels
/// off the map are clear. Pure, so tests read the bytes. Design D2.
public struct MinimapTerrainRaster: Equatable, Sendable {
    public let width: Int
    public let height: Int
    private let projection: MinimapProjection
    /// RGBA, row by row from the top.
    public private(set) var bytes: [UInt8]

    static let pixelsPerUnit = 2

    // The corner minimap is at most 240 points, 480 pixels on a Retina
    // screen; the Apple TV overview is about 1,700 points at 1x.
    #if os(tvOS)
    public static let maxWidth = 1024
    #else
    public static let maxWidth = 512
    #endif

    public init(terrain: [TerrainType], mapWidth: Int, mapHeight: Int, maxWidth: Int = Self.maxWidth) {
        let span = max(mapWidth + mapHeight, 1)
        width = max(2, min(span * Self.pixelsPerUnit, maxWidth - maxWidth % 2))
        height = width / 2
        projection = MinimapProjection(mapWidth: mapWidth, mapHeight: mapHeight, size: CGSize(width: width, height: height))
        bytes = [UInt8](repeating: 0, count: width * height * 4)
        for row in 0 ..< height {
            for column in 0 ..< width {
                paint(column: column, row: row, terrain: terrain)
            }
        }
    }

    /// Repaints only the tiles whose terrain differs from `old`, such as a
    /// forest felled or planted. Both grids are for this raster's map size.
    public mutating func repaint(from old: [TerrainType], to new: [TerrainType]) {
        let mapWidth = projection.mapWidth
        // A tile's diamond spans one unit of `u` and `v` each way.
        let reachX = Int(pixelsPerUnitAcross.rounded(.up)) + 1
        let reachY = Int((pixelsPerUnitAcross / 2).rounded(.up)) + 1
        for index in new.indices where new[index] != old[index] {
            let center = pixelCenter(tileX: index % mapWidth, tileY: index / mapWidth)
            for row in max(center.row - reachY, 0) ... min(center.row + reachY, height - 1) {
                for column in max(center.column - reachX, 0) ... min(center.column + reachX, width - 1) {
                    paint(column: column, row: row, terrain: new)
                }
            }
        }
    }

    private var pixelsPerUnitAcross: Double {
        Double(width) / Double(max(projection.mapWidth + projection.mapHeight, 1))
    }

    private mutating func paint(column: Int, row: Int, terrain: [TerrainType]) {
        let (tileX, tileY) = projection.tile(at: CGPoint(x: Double(column) + 0.5, y: Double(row) + 0.5))
        let x = Int(tileX.rounded())
        let y = Int(tileY.rounded())
        guard x >= 0, x < projection.mapWidth, y >= 0, y < projection.mapHeight else { return }
        let colour = MinimapPalette.colour(for: terrain[y * projection.mapWidth + x])
        let offset = (row * width + column) * 4
        bytes[offset] = colour.red
        bytes[offset + 1] = colour.green
        bytes[offset + 2] = colour.blue
        bytes[offset + 3] = colour.alpha
    }

    public func pixel(column: Int, row: Int) -> MinimapRGBA {
        let offset = (row * width + column) * 4
        return MinimapRGBA(red: bytes[offset], green: bytes[offset + 1], blue: bytes[offset + 2], alpha: bytes[offset + 3])
    }

    /// The pixel holding the center of tile (x, y).
    public func pixelCenter(tileX: Int, tileY: Int) -> (column: Int, row: Int) {
        let point = projection.point(tileX: Double(tileX), tileY: Double(tileY))
        return (Int(point.x), Int(point.y))
    }

    public func makeImage() -> CGImage? {
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
