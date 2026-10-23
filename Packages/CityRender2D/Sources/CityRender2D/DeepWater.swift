import CityCore
import CoreGraphics
import SpriteKit

/// Open water (issue #171): every water tile with no shore transition is drawn by one map-sized
/// backdrop sprite instead of a sprite each, so a zoomed-out archipelago is a few thousand nodes,
/// not tens of thousands. A shader repeats the water sprites' own pixels across the open-water tiles
/// and steps through their animation frames, so the sea looks as it did; shore transitions, ships
/// and wakes stay ordinary nodes over it.
public struct DeepWaterMask: Equatable, Sendable {
    public let width: Int
    public let height: Int
    /// Row-major, true where a tile is open water.
    let tiles: [Bool]

    public init(width: Int, height: Int, grid: [TerrainType], transitions: TerrainTransitionMap) {
        self.width = width
        self.height = height
        tiles = grid.indices.map { index in
            grid[index] == .water && transitions.transition(at: TileCoordinate(x: index % width, y: index / width)) == nil
        }
    }

    public func contains(_ coord: TileCoordinate) -> Bool {
        coord.x >= 0 && coord.x < width && coord.y >= 0 && coord.y < height && tiles[coord.y * width + coord.x]
    }

    /// One RGBA texel per tile, opaque where the tile is open water; row 0 is the texture's bottom.
    var texels: [UInt8] {
        var bytes = [UInt8](repeating: 0, count: tiles.count * 4)
        for index in tiles.indices where tiles[index] {
            bytes.replaceSubrange(index * 4 ..< index * 4 + 4, with: repeatElement(255, count: 4))
        }
        return bytes
    }
}

extension IsoWorldScene {
    public static let deepWaterNodeName = "deep-water"

    /// Shows the open water of `mask`, building the backdrop on first use.
    func showDeepWater(_ mask: DeepWaterMask) {
        guard mask != deepWaterMask else { return }
        deepWaterMask = mask
        let node = deepWaterNode ?? {
            let node = SKSpriteNode(color: .white, size: .zero)
            node.name = Self.deepWaterNodeName
            node.anchorPoint = .zero
            node.zPosition = -0.5
            node.shader = Self.makeDeepWaterShader()
            addChild(node)
            deepWaterNode = node
            return node
        }()
        let bounds = Self.mapBounds(width: mask.width, height: mask.height)
        node.position = bounds.origin
        node.size = bounds.size
        let maskTexture = SKTexture(data: Data(mask.texels), size: CGSize(width: mask.width, height: mask.height), flipped: false)
        maskTexture.filteringMode = .nearest
        node.shader?.uniformNamed("u_mask")?.textureValue = maskTexture
        node.shader?.uniformNamed("u_origin")?.vectorFloat2Value = vector_float2(Float(bounds.minX), Float(bounds.minY))
        node.shader?.uniformNamed("u_size")?.vectorFloat2Value = vector_float2(Float(bounds.width), Float(bounds.height))
        node.shader?.uniformNamed("u_tiles")?.vectorFloat2Value = vector_float2(Float(mask.width), Float(mask.height))
    }

    /// The scene rect that holds every tile of a `width` × `height` map.
    static func mapBounds(width: Int, height: Int) -> CGRect {
        let halfWidth = IsoMath.tileWidth / 2, halfHeight = IsoMath.tileHeight / 2
        let span = CGFloat(width + height)
        return CGRect(
            x: -CGFloat(height) * halfWidth,
            y: halfHeight - span * halfHeight,
            width: span * halfWidth,
            height: span * halfHeight
        )
    }

    /// The water frames, each laid out as 2 × 2 periods of the tile lattice (128 × 64 points) and
    /// stacked bottom to top, so the shader samples a period from the middle of a frame and linear
    /// filtering never reaches a neighbouring frame or the texture's edge.
    static let waterPeriods: SKTexture = {
        let frames = SpriteAnimation.entry(for: .terrain(.water))?.frameCount ?? 1
        let names = frames > 1 ? (0 ..< frames).map { "terrain-water-\($0)" } : ["terrain-water"]
        let images = names.compactMap { SpriteAtlas.textureOrPlaceholder(named: $0).cgImage() }
        let scale = CGFloat(images.first?.width ?? 64) / IsoMath.tileWidth
        let tile = CGSize(width: IsoMath.tileWidth * scale, height: IsoMath.tileHeight * scale)
        let frame = CGSize(width: tile.width * 2, height: tile.height * 2)
        guard let context = CGContext(
            data: nil, width: Int(frame.width), height: Int(frame.height) * max(1, images.count), bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        else { return SKTexture() }
        for (index, image) in images.enumerated() {
            let floor = CGFloat(index) * frame.height
            context.saveGState()
            context.clip(to: CGRect(x: 0, y: floor, width: frame.width, height: frame.height))
            // Tile centres sit on the lattice: every (32 i, 16 j) point with i + j even.
            for row in 0 ... 4 {
                for column in 0 ... 4 where (row + column).isMultiple(of: 2) {
                    let centre = CGPoint(x: CGFloat(column) * tile.width / 2, y: floor + CGFloat(row) * tile.height / 2)
                    context.draw(
                        image,
                        in: CGRect(x: centre.x - tile.width / 2, y: centre.y - tile.height / 2, width: tile.width, height: tile.height)
                    )
                }
            }
            context.restoreGState()
        }
        guard let strip = context.makeImage() else { return SKTexture() }
        let texture = SKTexture(cgImage: strip)
        texture.filteringMode = .linear
        return texture
    }()

    /// Scene point → tile (the inverse of `IsoMath.screenPoint(forTile:)`), mask lookup, then the water
    /// period under the point in the current frame.
    static func makeDeepWaterShader() -> SKShader {
        let entry = SpriteAnimation.entry(for: .terrain(.water))
        let frames = Double(max(1, entry?.frameCount ?? 1))
        let (halfWidth, halfHeight) = (Double(IsoMath.tileWidth / 2), Double(IsoMath.tileHeight / 2))
        // The water texture holds 2 × 2 lattice periods of 2 half-tiles across and down.
        let source = """
        void main() {
            vec2 p = u_origin + v_tex_coord * u_size;
            float c = floor((p.x / \(halfWidth) - p.y / \(halfHeight)) * 0.5 + 0.5);
            float r = floor((-p.x / \(halfWidth) - p.y / \(halfHeight)) * 0.5 + 0.5);
            float frame = floor(mod(u_time / \(entry?.timePerFrame ?? 1), \(frames)));
            vec2 period = vec2(\(halfWidth) + mod(p.x, \(2 * halfWidth)), \(halfHeight) + mod(p.y, \(2 * halfHeight)));
            float stripHeight = \(4 * halfHeight) * \(frames);
            vec4 water = texture2D(u_water, vec2(period.x / \(4 * halfWidth), (frame * \(4 * halfHeight) + period.y) / stripHeight));
            bool inside = c >= 0.0 && r >= 0.0 && c < u_tiles.x && r < u_tiles.y
                && texture2D(u_mask, vec2((c + 0.5) / u_tiles.x, (r + 0.5) / u_tiles.y)).a > 0.5;
            gl_FragColor = inside ? water : vec4(0.0);
        }
        """
        return SKShader(source: source, uniforms: [
            SKUniform(name: "u_water", texture: waterPeriods),
            SKUniform(name: "u_mask", texture: SKTexture()),
            SKUniform(name: "u_origin", vectorFloat2: .zero),
            SKUniform(name: "u_size", vectorFloat2: .zero),
            SKUniform(name: "u_tiles", vectorFloat2: .zero)
        ])
    }
}
