import CityCore
import CoreGraphics
import simd

/// The ground macro field (terrain-v2, design D1): one map-sized colour layer, multiplied over the
/// ground tiles at twice its value, so 0.5 grey leaves the ground as it is. Each map vertex gets a
/// colour from the terrain round it, world-space noise, occupancy and the season; texels between
/// vertices interpolate them, so neighbouring tiles differ smoothly and the tile lattice never shows.
public struct GroundMacroField: Sendable {
    /// Scene points per texel: 4 texels across a tile, 2 down.
    public static let pointsPerTexel: CGFloat = 16

    /// Texels across and down.
    public let width: Int
    public let height: Int
    /// RGBA, 8 bits a channel, rows from the top.
    public let pixels: [UInt8]
    /// Scene point of the texture's top-left corner.
    public let topLeft: CGPoint
    /// Each vertex's colour, row-major over (mapWidth + 1) × (mapHeight + 1), before the halving.
    let vertices: [SIMD3<Float>]
    let mapWidth: Int

    public init(width mapWidth: Int, height mapHeight: Int, grid: [TerrainType], occupied: Set<TileCoordinate>, season: Season) {
        self.mapWidth = mapWidth
        let look = Look(season)
        let shares = TerrainShares(width: mapWidth, height: mapHeight, grid: grid, occupied: occupied)
        var vertices = [SIMD3<Float>](repeating: .one, count: (mapWidth + 1) * (mapHeight + 1))
        for vy in 0 ... mapHeight {
            for vx in 0 ... mapWidth {
                vertices[vy * (mapWidth + 1) + vx] = look.colour(at: vx, vy, shares)
            }
        }
        self.vertices = vertices
        width = 2 * (mapWidth + mapHeight)
        height = mapWidth + mapHeight
        topLeft = CGPoint(x: -IsoMath.tileWidth / 2 * CGFloat(mapHeight), y: IsoMath.tileHeight / 2)
        pixels = Self.fill(vertices, mapWidth: mapWidth, mapHeight: mapHeight, size: (width, height), topLeft: topLeft)
    }

    /// The field at a vertex, as the multiplier it applies to the ground (1 is neutral).
    public func multiplier(atVertex vertex: TileCoordinate) -> SIMD3<Float> {
        vertices[vertex.y * (mapWidth + 1) + vertex.x]
    }

    /// Texels interpolate the vertex colours bilinearly; well off the map they stay neutral.
    private static func fill(
        _ vertices: [SIMD3<Float>], mapWidth: Int, mapHeight: Int, size: (width: Int, height: Int), topLeft: CGPoint
    ) -> [UInt8] {
        let (width, height) = size
        let halfWidth = Float(IsoMath.tileWidth) / 2, halfHeight = Float(IsoMath.tileHeight) / 2
        let scaled = vertices.map { simd_clamp($0 * 127.5, .zero, SIMD3(repeating: 255)) }
        var pixels = [UInt8](repeating: 128, count: width * height * 4)
        let step = Float(pointsPerTexel)
        let x0 = Float(topLeft.x) + step / 2, y0 = Float(topLeft.y) - step / 2
        let stride = mapWidth + 1
        let maxX = Float(mapWidth), maxY = Float(mapHeight)
        // Texels up to one texel outside the map still cover the edge tiles' outer corners: clamp them.
        let reach: Float = 0.75
        for row in 0 ..< height {
            let sceneY = y0 - Float(row) * step
            for column in 0 ..< width {
                let sceneX = x0 + Float(column) * step
                // `IsoMath.tileCoordinate(forScreenPoint:)`, plus half a tile from centre to vertex.
                let across = sceneX / halfWidth, down = -sceneY / halfHeight
                let rawX = (across + down) / 2 + 0.5, rawY = (down - across) / 2 + 0.5
                let base = (row * width + column) * 4
                pixels[base + 3] = 255
                guard rawX >= -reach, rawY >= -reach, rawX <= maxX + reach, rawY <= maxY + reach else { continue }
                let vx = simd_clamp(rawX, 0, maxX), vy = simd_clamp(rawY, 0, maxY)
                let ix = min(Int(vx), mapWidth - 1), iy = min(Int(vy), mapHeight - 1)
                let fx = vx - Float(ix), fy = vy - Float(iy)
                let corner = iy * stride + ix
                let top = scaled[corner] + (scaled[corner + 1] - scaled[corner]) * fx
                let bottom = scaled[corner + stride] + (scaled[corner + stride + 1] - scaled[corner + stride]) * fx
                let colour = (top + (bottom - top) * fy).rounded(.toNearestOrAwayFromZero)
                pixels[base] = UInt8(colour.x)
                pixels[base + 1] = UInt8(colour.y)
                pixels[base + 2] = UInt8(colour.z)
            }
        }
        return pixels
    }
}
