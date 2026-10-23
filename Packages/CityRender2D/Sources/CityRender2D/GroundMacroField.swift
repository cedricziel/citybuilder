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
    /// The scree cover over rock (design D8): premultiplied RGBA, alpha-blended between the ground
    /// tiles and the macro field.
    public let screePixels: [UInt8]
    let screeVertices: [SIMD4<Float>]
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
        topLeft = Self.corner(mapHeight: mapHeight)
        pixels = Self.fill(vertices.map { SIMD4($0 * 0.5, 1) }, neutral: SIMD4(0.5, 0.5, 0.5, 1), mapWidth: mapWidth, mapHeight: mapHeight)
        screeVertices = look.scree(shares)
        screePixels = Self.fill(screeVertices, neutral: .zero, mapWidth: mapWidth, mapHeight: mapHeight)
    }

    /// Scene point of the texture's top-left corner: the map's west vertex across, its north vertex down.
    private static func corner(mapHeight: Int) -> CGPoint {
        CGPoint(x: -IsoMath.tileWidth / 2 * CGFloat(mapHeight), y: IsoMath.tileHeight / 2)
    }

    /// How opaque the scree cover is at a vertex.
    public func screeOpacity(atVertex vertex: TileCoordinate) -> Float {
        screeVertices[vertex.y * (mapWidth + 1) + vertex.x].w
    }

    /// The field at a vertex, as the multiplier it applies to the ground (1 is neutral).
    public func multiplier(atVertex vertex: TileCoordinate) -> SIMD3<Float> {
        vertices[vertex.y * (mapWidth + 1) + vertex.x]
    }

    /// Texels interpolate the vertex values bilinearly; well off the map they take `neutral`. Values
    /// are RGBA in 0...1.
    private static func fill(_ values: [SIMD4<Float>], neutral: SIMD4<Float>, mapWidth: Int, mapHeight: Int) -> [UInt8] {
        let width = 2 * (mapWidth + mapHeight), height = mapWidth + mapHeight
        let topLeft = corner(mapHeight: mapHeight)
        let halfWidth = Float(IsoMath.tileWidth) / 2, halfHeight = Float(IsoMath.tileHeight) / 2
        let scaled = values.map { simd_clamp($0 * 255, .zero, SIMD4(repeating: 255)) }
        let outside = (neutral * 255).rounded(.toNearestOrAwayFromZero)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
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
                var colour = outside
                if rawX >= -reach, rawY >= -reach, rawX <= maxX + reach, rawY <= maxY + reach {
                    let vx = simd_clamp(rawX, 0, maxX), vy = simd_clamp(rawY, 0, maxY)
                    let ix = min(Int(vx), mapWidth - 1), iy = min(Int(vy), mapHeight - 1)
                    let fx = vx - Float(ix), fy = vy - Float(iy)
                    let corner = iy * stride + ix
                    let top = scaled[corner] + (scaled[corner + 1] - scaled[corner]) * fx
                    let bottom = scaled[corner + stride] + (scaled[corner + stride + 1] - scaled[corner + stride]) * fx
                    colour = (top + (bottom - top) * fy).rounded(.toNearestOrAwayFromZero)
                }
                let base = (row * width + column) * 4
                pixels[base] = UInt8(colour.x)
                pixels[base + 1] = UInt8(colour.y)
                pixels[base + 2] = UInt8(colour.z)
                pixels[base + 3] = UInt8(colour.w)
            }
        }
        return pixels
    }
}
