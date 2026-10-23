import CityCore
import CoreGraphics
import SpriteKit

/// Plain ground (issue #205): every tile whose ground is a plain grass, beach or water sprite, with
/// no transition, is drawn by one screen-sized backdrop sprite instead of a sprite each. A shader
/// finds the tile under each pixel, reads which look it shows, and draws that look's pixels with its
/// animation frames, each tile on its own phase as its sprite did. Transitions, trees and rocks,
/// buildings and every overlay stay ordinary nodes over it.
public struct GroundBackdropMap: Equatable, Sendable {
    /// The looks the backdrop draws, by row of its look strip: grass variants 0 to 3, beach, water.
    enum Look: UInt8, CaseIterable {
        case grass0 = 1, grass1, grass2, grass3, beach, water

        var kind: TerrainType {
            switch self {
            case .grass0, .grass1, .grass2, .grass3: .grass
            case .beach: .beach
            case .water: .water
            }
        }

        var variant: Int {
            Int(rawValue - Look.grass0.rawValue)
        }
    }

    public let width: Int
    public let height: Int
    /// Row-major look per tile, 0 where the tile keeps its own sprite.
    let looks: [UInt8]

    public init(width: Int, height: Int, grid: [TerrainType], transitions: TerrainTransitionMap) {
        self.width = width
        self.height = height
        let grassVariants = SpriteAtlas.terrainVariantCounts[.grass] ?? 1
        looks = grid.indices.map { index in
            let coord = TileCoordinate(x: index % width, y: index / width)
            guard transitions.transition(at: coord) == nil else { return 0 }
            // Forest and rock stand on grass (terrain-v2, design D3).
            switch TerrainObject.kinds.contains(grid[index]) ? .grass : grid[index] {
            case .grass: return Look.grass0.rawValue + UInt8(SpriteAtlas.variantIndex(coord: coord, count: grassVariants))
            case .beach: return Look.beach.rawValue
            case .water: return Look.water.rawValue
            default: return 0
            }
        }
    }

    /// Whether the backdrop draws the tile's ground.
    public func covers(_ coord: TileCoordinate) -> Bool {
        coord.x >= 0 && coord.x < width && coord.y >= 0 && coord.y < height && looks[coord.y * width + coord.x] != 0
    }

    /// One RGBA texel per tile, row 0 at the texture's bottom: the look in red, and in green the
    /// tile's animation phase, from its own hash.
    var texels: [UInt8] {
        var bytes = [UInt8](repeating: 0, count: looks.count * 4)
        for index in looks.indices where looks[index] != 0 {
            let phase = SpriteAtlas.tileHash(Int32(index % width), Int32(index / width), salt: 23) & 0xFF
            bytes[index * 4] = looks[index]
            bytes[index * 4 + 1] = UInt8(phase)
            bytes[index * 4 + 3] = 255
        }
        return bytes
    }
}

extension IsoWorldScene {
    public static let groundBackdropNodeName = "ground-backdrop"

    /// Shows the plain ground of `map`, building the backdrop on first use.
    func showGroundBackdrop(_ map: GroundBackdropMap) {
        guard map != groundBackdropMap else { return }
        groundBackdropMap = map
        let node = groundBackdropNode ?? {
            let node = SKSpriteNode(color: .white, size: .zero)
            node.name = Self.groundBackdropNodeName
            node.anchorPoint = .zero
            node.zPosition = -0.5
            node.shader = Self.makeGroundBackdropShader(looks: groundLookStrip(season: appliedSeason))
            addChild(node)
            groundBackdropNode = node
            return node
        }()
        let texture = SKTexture(data: Data(map.texels), size: CGSize(width: map.width, height: map.height), flipped: false)
        texture.filteringMode = .nearest
        node.shader?.uniformNamed("u_tiles")?.textureValue = texture
        node.shader?.uniformNamed("u_map")?.vectorFloat2Value = vector_float2(Float(map.width), Float(map.height))
    }

    /// Advances the backdrop's animation while motion runs, holds it while the game is paused, and
    /// rests every tile on frame 0 under Reduce Motion, like the building animations.
    func updateGroundMotion(now: TimeInterval) {
        let state = motionState(now: now)
        if state == .running {
            groundClock += now - (groundClockSeen ?? now)
        }
        groundClockSeen = now
        guard let shader = groundBackdropNode?.shader else { return }
        shader.uniformNamed("u_clock")?.floatValue = Float(groundClock)
        shader.uniformNamed("u_rest")?.floatValue = state == .stopped ? 1 : 0
    }

    /// Redraws the looks for a new season.
    func refreshGroundBackdropLooks() {
        groundBackdropNode?.shader?.uniformNamed("u_looks")?.textureValue = groundLookStrip(season: appliedSeason)
    }

    /// Spans the backdrop over `screen`, clamped to the map, so its shader runs only on pixels the
    /// camera can show.
    func fitGroundBackdrop(to screen: CGRect) {
        guard let node = groundBackdropNode, let map = groundBackdropMap else { return }
        let rect = screen.intersection(Self.mapBounds(width: map.width, height: map.height))
        node.isHidden = rect.isNull || rect.isEmpty
        guard !node.isHidden else { return }
        node.position = rect.origin
        node.size = rect.size
        node.shader?.uniformNamed("u_origin")?.vectorFloat2Value = vector_float2(Float(rect.minX), Float(rect.minY))
        node.shader?.uniformNamed("u_size")?.vectorFloat2Value = vector_float2(Float(rect.width), Float(rect.height))
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

    /// The most frames a look animates through: the strip's column count.
    static let groundLookFrames = GroundBackdropMap.Look.allCases
        .map { SpriteAnimation.entry(for: .terrain($0.kind))?.frameCount ?? 1 }.max() ?? 1

    /// Every look the backdrop draws in `season`, one row per look and one column per frame. Each
    /// cell is 2 × 2 tiles (128 × 64 points) with the look's tile in the middle and the kind's base
    /// tile round it, so the shader samples a tile from the middle of its cell and linear filtering
    /// meets the neighbours a tile has in the world, never a transparent corner. A look that does not
    /// animate repeats its sprite in every column.
    func groundLookStrip(season: Season) -> SKTexture {
        let looks = GroundBackdropMap.Look.allCases
        let names = looks.map { lookSpriteName($0, season: season) }
        let key = names.joined(separator: " ")
        if let hit = Self.lookStripCache[key] { return hit }
        let strip = Self.drawLookStrip(looks: looks, names: names, bases: looks.map { lookSpriteName($0, season: season, variant: 0) })
        Self.lookStripCache[key] = strip
        return strip
    }

    /// Strips already drawn, by the sprite names they show: the atlas never changes while the app runs.
    private nonisolated(unsafe) static var lookStripCache: [String: SKTexture] = [:]

    /// The sprite the backdrop shows on `coord`, nil where the tile keeps its own sprite.
    func groundSpriteName(at coord: TileCoordinate) -> String? {
        guard let map = groundBackdropMap, map.covers(coord),
              let look = GroundBackdropMap.Look(rawValue: map.looks[coord.y * map.width + coord.x])
        else { return nil }
        return lookSpriteName(look, season: appliedSeason)
    }

    private static func drawLookStrip(looks: [GroundBackdropMap.Look], names: [String], bases: [String]) -> SKTexture {
        let columns = groundLookFrames
        let probe = SpriteAtlas.textureOrPlaceholder(named: "terrain-grass").cgImage()
        let scale = CGFloat(probe.width) / IsoMath.tileWidth
        let tile = CGSize(width: IsoMath.tileWidth * scale, height: IsoMath.tileHeight * scale)
        let cell = CGSize(width: tile.width * 2, height: tile.height * 2)
        guard let context = CGContext(
            data: nil, width: Int(cell.width) * columns, height: Int(cell.height) * looks.count, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        else { return SKTexture() }
        for (row, look) in looks.enumerated() {
            let (name, base) = (names[row], bases[row])
            for column in 0 ..< columns {
                let origin = CGPoint(x: CGFloat(column) * cell.width, y: CGFloat(row) * cell.height)
                context.saveGState()
                context.clip(to: CGRect(origin: origin, size: cell))
                // The eight neighbours, then the look itself on top, centred in the cell.
                for (dx, dy) in [(-2, 0), (2, 0), (0, -2), (0, 2), (-1, -1), (1, -1), (-1, 1), (1, 1), (0, 0)] {
                    let image = frameImage(dx == 0 && dy == 0 ? name : base, kind: look.kind, frame: column)
                    let centre = CGPoint(
                        x: origin.x + cell.width / 2 + CGFloat(dx) * tile.width / 2,
                        y: origin.y + cell.height / 2 + CGFloat(dy) * tile.height / 2
                    )
                    context.draw(
                        image,
                        in: CGRect(x: centre.x - tile.width / 2, y: centre.y - tile.height / 2, width: tile.width, height: tile.height)
                    )
                }
                context.restoreGState()
            }
        }
        guard let strip = context.makeImage() else { return SKTexture() }
        let texture = SKTexture(cgImage: strip)
        texture.filteringMode = .linear
        return texture
    }

    /// The sprite a tile of `look` shows in `season`, as its own sprite would (`terrainSpriteName`).
    private func lookSpriteName(_ look: GroundBackdropMap.Look, season: Season, variant: Int? = nil) -> String {
        terrainSpriteName(kind: look.kind, season: season, variant: variant ?? look.variant)
    }

    /// Frame `frame` of a looping terrain sprite, or the sprite itself when it does not animate.
    private static func frameImage(_ name: String, kind: TerrainType, frame: Int) -> CGImage {
        let frames = SpriteAnimation.entry(for: .terrain(kind))?.frameCount ?? 0
        let framed = frames > 1 ? SpriteAtlas.texture(named: "\(name)-\(frame % frames)") : nil
        return (framed ?? SpriteAtlas.textureOrPlaceholder(named: name)).cgImage()
    }

    /// Scene point → tile (the inverse of `IsoMath.screenPoint(forTile:)`) → its look and phase →
    /// the look's pixels at the point's offset from the tile centre, in the tile's current frame.
    static func makeGroundBackdropShader(looks: SKTexture) -> SKShader {
        let (halfWidth, halfHeight) = (Double(IsoMath.tileWidth / 2), Double(IsoMath.tileHeight / 2))
        let rows = Double(GroundBackdropMap.Look.allCases.count)
        let columns = Double(groundLookFrames)
        // Per look row: frame count and seconds per frame, from the sprites' animation entries.
        let timing = GroundBackdropMap.Look.allCases.map { look -> (Double, Double) in
            let entry = SpriteAnimation.entry(for: .terrain(look.kind))
            return (Double(max(1, entry?.frameCount ?? 1)), entry?.timePerFrame ?? 1)
        }
        let frameChoice = timing.enumerated().map { row, timing in
            "row == \(Double(row)) ? vec2(\(timing.0), \(timing.1)) : "
        }.joined() + "vec2(1.0, 1.0)"
        let source = """
        void main() {
            vec2 p = u_origin + v_tex_coord * u_size;
            float fc = (p.x / \(halfWidth) - p.y / \(halfHeight)) * 0.5;
            float fr = (-p.x / \(halfWidth) - p.y / \(halfHeight)) * 0.5;
            float c = floor(fc + 0.5);
            float r = floor(fr + 0.5);
            vec4 tile = vec4(0.0);
            if (c >= 0.0 && r >= 0.0 && c < u_map.x && r < u_map.y) {
                tile = texture2D(u_tiles, vec2((c + 0.5) / u_map.x, (r + 0.5) / u_map.y));
            }
            if (tile.a < 0.5) {
                gl_FragColor = vec4(0.0);
            } else {
                float row = floor(tile.r * 255.0 + 0.5) - 1.0;
                vec2 timing = \(frameChoice);
                float frame = u_rest > 0.5 ? 0.0 : floor(mod(u_clock / timing.y + tile.g * timing.x, timing.x));
                vec2 offset = vec2((c - r) * \(halfWidth), -(c + r) * \(halfHeight));
                vec2 local = p - offset + vec2(\(2 * halfWidth), \(2 * halfHeight));
                vec2 uv = vec2((frame * \(4 * halfWidth) + local.x) / (\(4 * halfWidth) * \(columns)),
                               (row * \(4 * halfHeight) + local.y) / (\(4 * halfHeight) * \(rows)));
                gl_FragColor = texture2D(u_looks, uv);
            }
        }
        """
        return SKShader(source: source, uniforms: [
            SKUniform(name: "u_looks", texture: looks),
            SKUniform(name: "u_tiles", texture: SKTexture()),
            SKUniform(name: "u_origin", vectorFloat2: .zero),
            SKUniform(name: "u_size", vectorFloat2: .zero),
            SKUniform(name: "u_map", vectorFloat2: .zero),
            SKUniform(name: "u_clock", float: 0),
            SKUniform(name: "u_rest", float: 0)
        ])
    }
}
