import CityCore

/// How a road tile joins its neighbours (rendering-2_5d: Roads join their neighbours). Visual only.
///
/// The mask has an arm bit per paved edge neighbour (+x = 1, +y = 2, -x = 4, -y = 8), and a corner
/// bit where two adjacent arms are paved and so is the diagonal between them ((+x,+y) = 16,
/// (-x,+y) = 32, (-x,-y) = 64, (+x,-y) = 128). Paved means a road or the town center's footprint,
/// so the starter ring paves right up to the square. A road touching the town center, even
/// diagonally, is the cobbled plaza; every other road is worn earth. `scripts/art/roads.py` draws
/// one sprite per mask and surface.
public struct RoadLink: Hashable, Sendable {
    public let mask: Int
    public let plaza: Bool

    public init(mask: Int, plaza: Bool) {
        self.mask = mask
        self.plaza = plaza
    }

    public var assetName: String {
        plaza ? "building-road-plaza-c\(mask)" : "building-road-c\(mask)"
    }
}

public enum RoadLinks {
    struct Arm {
        let bit: Int, dx: Int, dy: Int
    }

    /// The quadrant between two arms (indices into `arms`).
    struct Corner {
        let bit: Int, first: Int, second: Int
    }

    static let arms = [Arm(bit: 1, dx: 1, dy: 0), Arm(bit: 2, dx: 0, dy: 1), Arm(bit: 4, dx: -1, dy: 0), Arm(bit: 8, dx: 0, dy: -1)]
    static let corners = [
        Corner(bit: 16, first: 0, second: 1), Corner(bit: 32, first: 2, second: 1),
        Corner(bit: 64, first: 2, second: 3), Corner(bit: 128, first: 0, second: 3)
    ]

    /// Every mask a road can have: any arms, plus any subset of the corners those arms allow.
    /// Mirrors `masks()` in `scripts/art/roads.py`.
    public static let allMasks: [Int] = (0 ..< 16).flatMap { armBits -> [Int] in
        let allowed = corners
            .filter { armBits & arms[$0.first].bit != 0 && armBits & arms[$0.second].bit != 0 }
            .map(\.bit)
        return (0 ..< 1 << allowed.count).map { subset in
            allowed.enumerated().reduce(armBits) { mask, corner in
                subset >> corner.offset & 1 == 1 ? mask | corner.element : mask
            }
        }
    }

    /// The link of every tile in `roads`, given the paved tiles and the town center's footprint.
    public static func links(
        roads: some Sequence<TileCoordinate>,
        paved: Set<TileCoordinate>,
        townCenter: Set<TileCoordinate>
    ) -> [TileCoordinate: RoadLink] {
        var links: [TileCoordinate: RoadLink] = [:]
        for tile in roads {
            let at = { (dx: Int, dy: Int) in TileCoordinate(x: tile.x + dx, y: tile.y + dy) }
            var mask = 0
            for arm in arms where paved.contains(at(arm.dx, arm.dy)) {
                mask |= arm.bit
            }
            for corner in corners {
                let first = arms[corner.first], second = arms[corner.second]
                if mask & first.bit != 0, mask & second.bit != 0, paved.contains(at(first.dx + second.dx, first.dy + second.dy)) {
                    mask |= corner.bit
                }
            }
            let plaza = (-1 ... 1).contains { dx in (-1 ... 1).contains { dy in townCenter.contains(at(dx, dy)) } }
            links[tile] = RoadLink(mask: mask, plaza: plaza)
        }
        return links
    }

    /// The links of every road in a snapshot.
    public static func links(in snapshot: WorldSnapshot) -> [TileCoordinate: RoadLink] {
        var roads: [TileCoordinate] = [], paved: Set<TileCoordinate> = [], townCenter: Set<TileCoordinate> = []
        for (tile, id) in snapshot.occupiedTiles {
            switch snapshot.buildings[id]?.kind {
            case .road:
                roads.append(tile)
                paved.insert(tile)
            case .townCenter:
                townCenter.insert(tile)
                paved.insert(tile)
            default:
                continue
            }
        }
        return links(roads: roads, paved: paved, townCenter: townCenter)
    }
}
