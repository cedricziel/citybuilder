import CityCore
import simd

/// What the terrain round each map vertex is made of, blurred over about half a tile: the share
/// of forest, mountain, water and beach tiles, whether an occupied tile touches it (worn), and how
/// far out to sea it lies (depth: 0 at the shore, 1 four or more tiles out).
struct TerrainShares {
    static let forest = 0, mountain = 1, water = 2, beach = 3, worn = 4, depth = 5

    let stride: Int
    let values: [SIMD8<Float>]

    init(width: Int, height: Int, grid: [TerrainType], occupied: Set<TileCoordinate>) {
        let stride = width + 1
        self.stride = stride
        let distance = Self.distanceToLand(width: width, grid: grid)
        var tiles = [SIMD8<Float>](repeating: .zero, count: width * height)
        for index in grid.indices {
            switch grid[index] {
            case .forest: tiles[index][Self.forest] = 1
            case .mountain: tiles[index][Self.mountain] = 1
            case .water: tiles[index][Self.water] = 1
            case .beach: tiles[index][Self.beach] = 1
            case .grass: break
            }
            tiles[index][Self.depth] = min(1, Float(max(distance[index] - 1, 0)) / 4)
        }
        for tile in occupied where tile.x >= 0 && tile.x < width && tile.y >= 0 && tile.y < height {
            tiles[tile.y * width + tile.x][Self.worn] = 1
        }
        var values = [SIMD8<Float>](repeating: .zero, count: stride * (height + 1))
        for vy in 0 ... height {
            for vx in 0 ... width {
                var sum = SIMD8<Float>.zero, count: Float = 0, worn: Float = 0, depth: Float = 1
                for (dx, dy) in TerrainCorners.tilesAroundVertex {
                    let x = vx + dx, y = vy + dy
                    guard x >= 0, x < width, y >= 0, y < height else { continue }
                    let tile = tiles[y * width + x]
                    sum += tile
                    count += 1
                    worn = max(worn, tile[Self.worn])
                    depth = min(depth, tile[Self.depth])
                }
                var value = count > 0 ? sum / count : .zero
                value[Self.worn] = worn
                value[Self.depth] = count > 0 ? depth : 0
                values[vy * stride + vx] = value
            }
        }
        self.values = Self.blur(values, stride: stride)
    }

    /// Breadth-first distance in tiles from every tile to the nearest land tile, over edge neighbours.
    static func distanceToLand(width: Int, grid: [TerrainType]) -> [Int] {
        var distance = grid.map { $0 == .water ? Int.max : 0 }
        var frontier = distance.indices.filter { distance[$0] == 0 }
        var next: [Int] = []
        var step = 0
        while !frontier.isEmpty {
            step += 1
            for index in frontier {
                let x = index % width
                func visit(_ neighbour: Int) {
                    guard distance[neighbour] == Int.max else { return }
                    distance[neighbour] = step
                    next.append(neighbour)
                }
                if x + 1 < width { visit(index + 1) }
                if x > 0 { visit(index - 1) }
                if index + width < distance.count { visit(index + width) }
                if index >= width { visit(index - width) }
            }
            frontier = next
            next.removeAll(keepingCapacity: true)
        }
        return distance
    }

    /// A [1 2 1] / 4 blur along both axes of the vertex grid.
    static func blur(_ field: [SIMD8<Float>], stride: Int) -> [SIMD8<Float>] {
        let rows = field.count / stride
        let across = pass(field) { index in (index % stride > 0 ? 1 : 0, index % stride < stride - 1 ? 1 : 0) }
        return pass(across) { index in (index / stride > 0 ? stride : 0, index / stride < rows - 1 ? stride : 0) }
    }

    /// One [1 2 1] / 4 pass; `reach` gives the offsets back and forward from each index (0 at an edge).
    private static func pass(_ field: [SIMD8<Float>], reach: (Int) -> (Int, Int)) -> [SIMD8<Float>] {
        field.indices.map { index in
            let (back, forward) = reach(index)
            return (field[index - back] + 2 * field[index] + field[index + forward]) / 4
        }
    }
}

extension GroundMacroField {
    /// The palette for one season. Colours are multipliers on the lit ground: 1 leaves it unchanged.
    struct Look {
        var dry: SIMD3<Float>
        var lush: SIMD3<Float>
        var fallow: SIMD3<Float>
        var mottle: Float
        var floor: SIMD3<Float>
        var worn: SIMD3<Float>
        var rock = SIMD3<Float>(0.92, 0.88, 0.84)
        var wetSand = SIMD3<Float>(0.84, 0.84, 0.88)
        var shallow = SIMD3<Float>(1.14, 1.28, 1.12)
        var deep = SIMD3<Float>(0.55, 0.68, 0.90)
        /// Lit scree, grey-brown and a touch warm, matched to the lit ground tiles; snow in winter.
        var screeColour = SIMD3<Float>(0.56, 0.52, 0.46)

        /// The season whose look `season` shows: spring and summer share one.
        static func season(of season: Season) -> Season {
            season == .summer ? .spring : season
        }

        init(_ season: Season) {
            switch season {
            case .spring, .summer:
                dry = SIMD3(1.22, 1.10, 0.72)
                lush = SIMD3(0.78, 0.92, 0.78)
                fallow = SIMD3(1.10, 0.96, 0.74)
                mottle = 0.08
                floor = SIMD3(0.66, 0.70, 0.62)
                worn = SIMD3(1.06, 0.94, 0.76)
            case .autumn:
                // The autumn grass is already ochre: lift and darken it, barely warm it further.
                dry = SIMD3(1.12, 1.06, 0.90)
                lush = SIMD3(0.86, 0.92, 0.88)
                fallow = SIMD3(1.04, 0.94, 0.84)
                mottle = 0.08
                floor = SIMD3(0.70, 0.68, 0.60)
                worn = SIMD3(1.04, 0.92, 0.76)
            case .winter:
                screeColour = SIMD3(0.80, 0.82, 0.86)
                dry = SIMD3(1.03, 1.03, 1.02)
                lush = SIMD3(0.96, 0.97, 0.99)
                fallow = SIMD3(1, 1, 1)
                mottle = 0.03
                floor = SIMD3(0.92, 0.93, 0.96)
                worn = .one
            }
        }

        func colour(at vx: Int, _ vy: Int, _ shares: TerrainShares) -> SIMD3<Float> {
            let share = shares.values[vy * shares.stride + vx]
            let x = Float(vx), y = Float(vy)
            let meadow = Noise.fbm(x, y, cell: 7, salt: 1)
            let dryness = simd_clamp(meadow, -1, 1)
            var colour = dryness > 0 ? mix(.one, dry, dryness) : mix(.one, lush, -dryness)
            colour *= mix(.one, fallow, simd_clamp(Noise.fbm(x, y, cell: 5, salt: 3) * 1.5 - 0.5, 0, 1))
            colour *= 1 + mottle * Noise.value(x / 1.5, y / 1.5, 2)
            let meadowland = (1 - share[TerrainShares.water]) * (1 - share[TerrainShares.beach]) * (1 - share[TerrainShares.mountain])
            colour = mix(.one, colour, meadowland)
            colour *= mix(.one, floor, min(1, share[TerrainShares.forest] * 1.3))
            colour *= mix(.one, rock, min(1, share[TerrainShares.mountain] * 1.3))
            colour *= mix(.one, worn, share[TerrainShares.worn])
            colour *= mix(.one, wetSand, min(1, share[TerrainShares.beach] * share[TerrainShares.water] * 4))
            // Only where water outweighs sand, or the waterside half of every beach turns teal.
            let sea = simd_clamp((share[TerrainShares.water] - share[TerrainShares.beach]) * 1.5, 0, 1)
            colour *= mix(.one, mix(shallow, deep, share[TerrainShares.depth]), sea)
            return colour
        }

        /// The scree over rock ground, premultiplied: opaque well inside a rock region, fading
        /// across its edge, with gritty light and dark patches. Snow lies on it in winter.
        func scree(_ shares: TerrainShares) -> [SIMD4<Float>] {
            let stride = shares.stride
            return shares.values.indices.map { index in
                let rock = shares.values[index][TerrainShares.mountain]
                let opacity = simd_clamp(rock * 1.6 - 0.35, 0, 1) * 0.9
                let grit = Noise.value(Float(index % stride) * 1.7, Float(index / stride) * 1.7, 7)
                let colour = screeColour * (1 + 0.12 * grit)
                return SIMD4(colour * opacity, opacity)
            }
        }

        private func mix(_ from: SIMD3<Float>, _ to: SIMD3<Float>, _ amount: Float) -> SIMD3<Float> {
            from + (to - from) * amount
        }
    }
}

/// Smooth value noise on the vertex lattice, from an integer hash: the same map always looks the same.
enum Noise {
    /// About -1...1, with features about `cell` vertices across.
    static func fbm(_ x: Float, _ y: Float, cell: Float, salt: UInt32) -> Float {
        (0.6 * value(x / cell, y / cell, salt) + 0.3 * value(2 * x / cell, 2 * y / cell, salt &+ 17)
            + 0.1 * value(4 * x / cell, 4 * y / cell, salt &+ 31)) * 1.6
    }

    static func value(_ x: Float, _ y: Float, _ salt: UInt32) -> Float {
        let x0 = x.rounded(.down), y0 = y.rounded(.down)
        let fx = smooth(x - x0), fy = smooth(y - y0)
        let ix = Int32(x0), iy = Int32(y0)
        let top = lattice(ix, iy, salt) * (1 - fx) + lattice(ix + 1, iy, salt) * fx
        let bottom = lattice(ix, iy + 1, salt) * (1 - fx) + lattice(ix + 1, iy + 1, salt) * fx
        return top * (1 - fy) + bottom * fy
    }

    private static func smooth(_ fraction: Float) -> Float {
        fraction * fraction * (3 - 2 * fraction)
    }

    /// -1...1 per lattice point.
    private static func lattice(_ x: Int32, _ y: Int32, _ salt: UInt32) -> Float {
        Float(SpriteAtlas.tileHash(x, y, salt: salt) & 0xFFFF) / 32767.5 - 1
    }
}
