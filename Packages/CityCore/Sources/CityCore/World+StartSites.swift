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
    /// Most road tiles from a town center's road ring to its nearest mine site.
    static let starterMineRoadReach = 10
    /// The rock outcrop raised when no mine site is that near.
    static let starterMineOutcrop = Footprint(width: 3, height: 3)
    /// Farthest a grove's corner may be from its target, per axis.
    static let groveSearchReach = 12
    /// Grass tiles the grove's clearing adds at most: a site with fewer
    /// than 150 − 4 grass cannot qualify, so its grove is not tried.
    static let groveClearing = 4

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
        for y in stride(from: ys.lowerBound, through: ys.upperBound - hut.height + 1, by: 1) {
            for x in stride(from: xs.lowerBound, through: xs.upperBound - hut.width + 1, by: 1) {
                let site = TileCoordinate(x: x, y: y)
                let onFreeGrass = hut.tiles(anchor: site).allSatisfy {
                    terrain(at: $0) == .grass && occupiedTiles[$0] == nil
                }
                if onFreeGrass {
                    bestTrees = max(bestTrees, forestTiles(inCatchmentOf: .lumberjackHut, at: site))
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
        let maxX = island.bounds.maxX - footprint.width + 1
        let maxY = island.bounds.maxY - footprint.height + 1
        guard island.bounds.minX <= maxX, island.bounds.minY <= maxY else { return nil }
        let candidates = Self.candidates(
            around: Self.startTarget(of: island), xs: island.bounds.minX ... maxX, ys: island.bounds.minY ... maxY
        )
        var grassiest: (anchor: TileCoordinate, grass: Int)?
        for anchor in candidates where ringSquareIsFreeGrass(anchor, island: island.id, tileToIsland: tileToIsland) {
            let (xs, ys) = startBounds(ofTownCenterAt: anchor)
            let land = landCounts(xs: xs, ys: ys)
            let roomy = land.mountain * 4 <= land.tiles && land.grass + Self.groveClearing >= StartArea.minimumGrass
            let grassLeft = roomy
                ? grassAfterGrove(besideTownCenterAt: anchor, island: island.id, tileToIsland: tileToIsland) : 0
            if grassLeft >= StartArea.minimumGrass { return StartSite(anchor: anchor, rule: .fair) }
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

    /// Grass in the start area once the grove for a town center at
    /// `anchor` is planted, so the site is measured as it will be.
    private func grassAfterGrove(
        besideTownCenterAt anchor: TileCoordinate,
        island: IslandID,
        tileToIsland: [TileCoordinate: IslandID]
    ) -> Int {
        var probe = self
        probe.plantStarterGrove(besideTownCenterAt: anchor, island: island, tileToIsland: tileToIsland)
        let (xs, ys) = startBounds(ofTownCenterAt: anchor)
        return probe.landCounts(xs: xs, ys: ys).grass
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

    /// Makes sure a 2×2 square where a mine fits once Mining is researched
    /// lies at most `starterMineRoadReach` road tiles from the town
    /// center's road ring, clear of the ring, which the starter roads take
    /// later. When none does, raises the nearest 3×3 grass square (then
    /// grass or forest) outside the start area to mountain. When none fits,
    /// the nearest site may stay farther out; if the island holds no site
    /// at all, raises the first grass
    /// neighbour of its mountains, nearest the town center first, that
    /// makes one, else the first forest neighbour. Tiles in the start area
    /// stay as they are. Spec: `world-terrain` / Starter mine site.
    mutating func raiseStarterMineSite(
        besideTownCenterAt anchor: TileCoordinate,
        island: Island,
        tileToIsland: [TileCoordinate: IslandID]
    ) {
        var probe = self
        probe.research.markResearched(.mining)
        let bounds = island.bounds
        let islandTiles = (bounds.minY ... bounds.maxY).flatMap { y in
            (bounds.minX ... bounds.maxX).map { TileCoordinate(x: $0, y: y) }
        }.filter { tileToIsland[$0] == island.id }
        let ring = Set(Self.ringSquare(of: anchor))
        let footprint = BuildingCatalog.spec(for: .mine).footprint
        func isMineSite(_ corner: TileCoordinate) -> Bool {
            !footprint.tiles(anchor: corner).contains(where: ring.contains)
                && probe.siteRejection(.mine, at: corner, for: .player, tileToIsland: tileToIsland) == nil
        }
        let roads = roadSteps(fromRingOf: anchor, island: island.id, tileToIsland: tileToIsland)
        let stepsToSite = { (corner: TileCoordinate) in Self.sideNeighbours(of: footprint, at: corner).compactMap { roads[$0] }.min() }
        guard !islandTiles.contains(where: { stepsToSite($0) != nil && isMineSite($0) }) else { return }
        let (startXs, startYs) = startBounds(ofTownCenterAt: anchor)
        let occupied = occupiedTiles
        let isRaisable = { (tile: TileCoordinate) in
            tileToIsland[tile] == island.id && occupied[tile] == nil && !(startXs.contains(tile.x) && startYs.contains(tile.y))
        }
        if raiseNearMineOutcrop(
            among: islandTiles,
            raisable: { isRaisable($0) && !ring.contains($0) },
            roads: roads,
            probe: probe,
            tileToIsland: tileToIsland
        ) {
            return
        }
        guard !islandTiles.contains(where: isMineSite) else { return }
        func distance(_ tile: TileCoordinate) -> Int {
            (tile.x - anchor.x) * (tile.x - anchor.x) + (tile.y - anchor.y) * (tile.y - anchor.y)
        }
        let mountains = islandTiles.filter { terrain(at: $0) == .mountain }
            .sorted { (distance($0), $0.y, $0.x) < (distance($1), $1.y, $1.x) }
        // Grass first, so the trees a hut site counts on stay.
        for raised in [TerrainType.grass, .forest] {
            for mountain in mountains {
                for (dx, dy) in [(1, 0), (0, 1), (-1, 0), (0, -1)] {
                    let tile = TileCoordinate(x: mountain.x + dx, y: mountain.y + dy)
                    guard terrain(at: tile) == raised, isRaisable(tile) else { continue }
                    let index = tile.y * mapWidth + tile.x
                    probe.terrainGrid[index] = .mountain
                    // A new site holds the raised tile, so one of the four
                    // squares around it.
                    let corners = [(0, 0), (-1, 0), (0, -1), (-1, -1)].map { TileCoordinate(x: tile.x + $0.0, y: tile.y + $0.1) }
                    if corners.contains(where: isMineSite) {
                        terrainGrid[index] = .mountain
                        return
                    }
                    probe.terrainGrid[index] = raised
                }
            }
        }
    }

    /// Raises the 3×3 outcrop nearest the road ring, by the road tiles in
    /// `roads` beside it, then by row and column, whose tiles are all
    /// `raisable` grass (then grass or forest) and that holds a mine site
    /// once it is mountain. A 3×3 keeps a rock crag in its middle, where a
    /// 2×2 would be all edge and draw as scree. Returns false when none
    /// fits. `probe` is this world with Mining researched.
    private mutating func raiseNearMineOutcrop(
        among islandTiles: [TileCoordinate],
        raisable: (TileCoordinate) -> Bool,
        roads: [TileCoordinate: Int],
        probe: World,
        tileToIsland: [TileCoordinate: IslandID]
    ) -> Bool {
        let outcrop = Self.starterMineOutcrop
        // Grass squares first, so the trees a hut site counts on stay.
        for terrains in [Set([TerrainType.grass]), [.grass, .forest]] {
            let squares = islandTiles.compactMap { corner -> (steps: Int, corner: TileCoordinate)? in
                guard outcrop.tiles(anchor: corner).allSatisfy({ terrains.contains(terrain(at: $0) ?? .water) && raisable($0) }),
                      let steps = Self.sideNeighbours(of: outcrop, at: corner).compactMap({ roads[$0] }).min()
                else { return nil }
                return (steps, corner)
            }
            for square in squares.sorted(by: { ($0.steps, $0.corner.y, $0.corner.x) < ($1.steps, $1.corner.y, $1.corner.x) }) {
                var raised = probe
                for tile in outcrop.tiles(anchor: square.corner) {
                    raised.terrainGrid[tile.y * mapWidth + tile.x] = .mountain
                }
                // Every side tile of a 3×3 touches one of the 2×2 squares inside it.
                let sites = [(0, 0), (1, 0), (0, 1), (1, 1)].map { TileCoordinate(x: square.corner.x + $0.0, y: square.corner.y + $0.1) }
                guard sites.contains(where: { raised.siteRejection(.mine, at: $0, for: .player, tileToIsland: tileToIsland) == nil })
                else { continue }
                terrainGrid = raised.terrainGrid
                return true
            }
        }
        return false
    }

    /// Road tiles from the town center's road ring, by land on its island: 0 for a ring tile, n for a
    /// tile n steps beyond it, up to `starterMineRoadReach`. Roads may cross forest and mountain.
    func roadSteps(
        fromRingOf anchor: TileCoordinate, island: IslandID, tileToIsland: [TileCoordinate: IslandID]
    ) -> [TileCoordinate: Int] {
        var steps: [TileCoordinate: Int] = [:]
        // The ring is free at world generation and road once the starter roads are laid.
        var queue = Self.ringSquare(of: anchor).filter { tile in
            tileToIsland[tile] == island && occupiedTiles[tile].map { buildings[$0]?.kind == .road } ?? true
        }
        for tile in queue {
            steps[tile] = 0
        }
        var head = 0
        while head < queue.count {
            let tile = queue[head]
            head += 1
            guard let step = steps[tile], step < Self.starterMineRoadReach else { continue }
            let free = Self.sideNeighbours(of: Footprint(width: 1, height: 1), at: tile).filter { next in
                steps[next] == nil && tileToIsland[next] == island && occupiedTiles[next] == nil
            }
            for next in free {
                steps[next] = step + 1
                queue.append(next)
            }
        }
        return steps
    }

    /// The tiles beside a footprint at `anchor`: right, lower, left and upper neighbours of its edge
    /// tiles, outside it.
    static func sideNeighbours(of footprint: Footprint, at anchor: TileCoordinate) -> [TileCoordinate] {
        let xs = anchor.x ..< anchor.x + footprint.width, ys = anchor.y ..< anchor.y + footprint.height
        return ys.flatMap { y in [TileCoordinate(x: xs.upperBound, y: y), TileCoordinate(x: xs.lowerBound - 1, y: y)] }
            + xs.flatMap { x in [TileCoordinate(x: x, y: ys.upperBound), TileCoordinate(x: x, y: ys.lowerBound - 1)] }
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
