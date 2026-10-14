import Foundation

/// How world generation chose a town center's anchor. Spec:
/// `world-terrain` / Fair start sites.
enum StartSiteRule: Equatable {
    /// The nearest anchor meeting the fair start thresholds.
    case fair
    /// No anchor met them: the all-grass 5×5 square with the most grass.
    case grassiest
    /// No all-grass 5×5 square: the nearest free 3×3 land footprint.
    case anyLand
}

struct StartSite: Equatable {
    let anchor: TileCoordinate
    let rule: StartSiteRule
}

/// The tiles within 8 of a town center's footprint, measured for
/// fairness. Spec: `world-terrain` / Fair start sites.
struct StartArea: Equatable, CustomStringConvertible {
    let grass: Int
    let mountain: Int
    let tiles: Int
    /// Most unoccupied forest in reach of a lumberjack hut on free grass
    /// inside the area.
    let hutSiteTrees: Int

    static let minimumGrass = 150
    static let minimumHutSiteTrees = 12

    var isFair: Bool {
        grass >= Self.minimumGrass && mountain * 4 <= tiles && hutSiteTrees >= Self.minimumHutSiteTrees
    }

    var description: String {
        "\(grass) grass, \(mountain) of \(tiles) mountain, hut site \(hutSiteTrees) trees"
    }
}

extension World {
    /// Chebyshev reach of the start area beyond the town center footprint.
    static let startAreaReach = 8
    /// Side of the starter grove.
    static let groveSide = 6
    /// Farthest a grove's corner may be from its target, per axis.
    static let groveSearchReach = 12

    /// The anchor that would centre a 3×3 town center on the island's
    /// bounding box.
    static func startTarget(of island: Island) -> TileCoordinate {
        let footprint = BuildingCatalog.spec(for: .townCenter).footprint
        return TileCoordinate(
            x: (island.bounds.minX + island.bounds.maxX) / 2 - footprint.width / 2,
            y: (island.bounds.minY + island.bounds.maxY) / 2 - footprint.height / 2
        )
    }

    /// Grass, mountain and the best lumberjack hut site around a town
    /// center anchored at `anchor`, with today's terrain and occupancy.
    func startArea(ofTownCenterAt anchor: TileCoordinate) -> StartArea {
        let (xs, ys) = startBounds(ofTownCenterAt: anchor)
        let land = landCounts(xs: xs, ys: ys)
        let hut = BuildingCatalog.spec(for: .lumberjackHut).footprint
        var bestTrees = 0
        for y in ys.lowerBound ... ys.upperBound - hut.height + 1 {
            for x in xs.lowerBound ... xs.upperBound - hut.width + 1 {
                let site = TileCoordinate(x: x, y: y)
                let onFreeGrass = hut.tiles(anchor: site).allSatisfy {
                    terrain(at: $0) == .grass && occupiedTiles[$0] == nil
                }
                if onFreeGrass {
                    bestTrees = max(bestTrees, forestTiles(inCatchmentOf: site, footprint: hut))
                }
            }
        }
        return StartArea(grass: land.grass, mountain: land.mountain, tiles: land.tiles, hutSiteTrees: bestTrees)
    }

    /// The start area's columns and rows, clipped to the map.
    private func startBounds(ofTownCenterAt anchor: TileCoordinate) -> (ClosedRange<Int>, ClosedRange<Int>) {
        let reach = Self.startAreaReach
        let footprint = BuildingCatalog.spec(for: .townCenter).footprint
        return (
            max(0, anchor.x - reach) ... min(mapWidth - 1, anchor.x + footprint.width - 1 + reach),
            max(0, anchor.y - reach) ... min(mapHeight - 1, anchor.y + footprint.height - 1 + reach)
        )
    }

    /// Grass and mountain in the area, with no hut site measured.
    private func landCounts(xs: ClosedRange<Int>, ys: ClosedRange<Int>) -> StartArea {
        var grass = 0
        var mountain = 0
        for y in ys {
            for x in xs {
                switch terrainGrid[y * mapWidth + x] {
                case .grass: grass += 1
                case .mountain: mountain += 1
                default: break
                }
            }
        }
        return StartArea(grass: grass, mountain: mountain, tiles: xs.count * ys.count, hutSiteTrees: 0)
    }

    /// Where world generation puts the island's town center, and which
    /// rule chose it (design D1, D2, D4). Nil when no 3×3 land fits.
    func townCenterSite(on island: Island, tileToIsland: [TileCoordinate: IslandID]) -> StartSite? {
        let footprint = BuildingCatalog.spec(for: .townCenter).footprint
        let candidates = Self.candidates(
            around: Self.startTarget(of: island),
            xs: island.bounds.minX ... island.bounds.maxX - footprint.width + 1,
            ys: island.bounds.minY ... island.bounds.maxY - footprint.height + 1
        )
        var grassiest: (anchor: TileCoordinate, grass: Int)?
        for anchor in candidates where ringSquareIsFreeGrass(anchor, island: island.id, tileToIsland: tileToIsland) {
            let (xs, ys) = startBounds(ofTownCenterAt: anchor)
            let land = landCounts(xs: xs, ys: ys)
            if land.grass >= StartArea.minimumGrass, land.mountain * 4 <= land.tiles {
                return StartSite(anchor: anchor, rule: .fair)
            }
            if land.grass > grassiest?.grass ?? -1 { grassiest = (anchor, land.grass) }
        }
        if let grassiest { return StartSite(anchor: grassiest.anchor, rule: .grassiest) }
        let landSite = candidates.first { anchor in
            footprint.tiles(anchor: anchor).allSatisfy {
                tileToIsland[$0] == island.id && occupiedTiles[$0] == nil
            }
        }
        return landSite.map { StartSite(anchor: $0, rule: .anyLand) }
    }

    /// Plants the starter grove nearest the town center at `anchor`:
    /// forest with a 2×2 grass clearing in the middle (design D3).
    /// Plants nothing when no square qualifies.
    mutating func plantStarterGrove(
        besideTownCenterAt anchor: TileCoordinate,
        island: IslandID,
        tileToIsland: [TileCoordinate: IslandID]
    ) {
        let grove = Footprint(width: Self.groveSide, height: Self.groveSide)
        let target = TileCoordinate(x: anchor.x - 2, y: anchor.y - 2)
        let reach = Self.groveSearchReach
        let ring = Set(Self.ringSquare(of: anchor))
        let corner = Self.candidates(
            around: target, xs: target.x - reach ... target.x + reach, ys: target.y - reach ... target.y + reach
        ).first { corner in
            grove.tiles(anchor: corner).allSatisfy { tile in
                let kind = terrain(at: tile)
                return (kind == .grass || kind == .forest) && tileToIsland[tile] == island
                    && occupiedTiles[tile] == nil && !ring.contains(tile)
            }
        }
        guard let corner else { return }
        for tile in grove.tiles(anchor: corner) {
            let clearing = (2 ... 3).contains(tile.x - corner.x) && (2 ... 3).contains(tile.y - corner.y)
            terrainGrid[tile.y * mapWidth + tile.x] = clearing ? .grass : .forest
        }
    }

    /// Points the camera at the middle of the player's home town center:
    /// the one on the island under the map's centre tile, else the
    /// lowest-ID one. Spec: `world-terrain` / New game camera starts on
    /// the home town center.
    mutating func centerCameraOnHomeTownCenter() {
        let tileToIsland = tileToIslandMap()
        let home = tileToIsland[TileCoordinate(x: mapWidth / 2, y: mapHeight / 2)]
        let centers = buildings.values
            .filter { $0.kind == .townCenter && $0.owner == .player }
            .sorted { $0.id.raw < $1.id.raw }
        guard let center = centers.first(where: { home != nil && tileToIsland[$0.anchor] == home }) ?? centers.first
        else { return }
        let footprint = BuildingCatalog.spec(for: .townCenter).footprint
        camera.centerX = Double(center.anchor.x) + Double(footprint.width) / 2
        camera.centerY = Double(center.anchor.y) + Double(footprint.height) / 2
    }

    /// Anchors in the ranges, nearest `target` first by squared distance,
    /// then by row, then by column.
    private static func candidates(around target: TileCoordinate, xs: ClosedRange<Int>, ys: ClosedRange<Int>) -> [TileCoordinate] {
        var anchors: [(distance: Int, tile: TileCoordinate)] = []
        anchors.reserveCapacity(xs.count * ys.count)
        for y in ys {
            for x in xs {
                let dx = x - target.x, dy = y - target.y
                anchors.append((dx * dx + dy * dy, TileCoordinate(x: x, y: y)))
            }
        }
        return anchors
            .sorted { ($0.distance, $0.tile.y, $0.tile.x) < ($1.distance, $1.tile.y, $1.tile.x) }
            .map(\.tile)
    }

    /// The town center footprint and its starter road ring.
    static func ringSquare(of anchor: TileCoordinate) -> [TileCoordinate] {
        let footprint = BuildingCatalog.spec(for: .townCenter).footprint
        return Footprint(width: footprint.width + 2, height: footprint.height + 2)
            .tiles(anchor: TileCoordinate(x: anchor.x - 1, y: anchor.y - 1))
    }

    private func ringSquareIsFreeGrass(_ anchor: TileCoordinate, island: IslandID, tileToIsland: [TileCoordinate: IslandID]) -> Bool {
        Self.ringSquare(of: anchor).allSatisfy {
            terrain(at: $0) == .grass && tileToIsland[$0] == island && occupiedTiles[$0] == nil
        }
    }
}
