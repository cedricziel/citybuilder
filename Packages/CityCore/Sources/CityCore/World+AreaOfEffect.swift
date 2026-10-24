import Foundation

/// What a building reaches, for the map to show while the building is placed or selected. Spec:
/// `rendering-2_5d` / Areas of effect while placing and selecting.
public struct AreaOfEffect: Equatable, Sendable {
    /// How far from the cursor, in tiles, placing a building with a terrain requirement looks for sites.
    public static let siteSearchRadius = 6

    /// The tiles to outline and tint.
    public let tiles: Set<TileCoordinate>
    /// The tiles the building would work, row-major: trees for a lumberjack hut, open grass for a
    /// forester, the required terrain of the sites for a mine.
    public let targets: [TileCoordinate]
    /// The number the count capsule shows: the targets for a catchment; for a site search, the tiles
    /// of the required terrain under the plot, or nil where the plot is no valid site.
    public let count: Int?

    public init(tiles: Set<TileCoordinate>, targets: [TileCoordinate], count: Int?) {
        self.tiles = tiles
        self.targets = targets
        self.count = count
    }
}

public extension World {
    /// The area a `kind` at `anchor` reaches: its catchment, or, while `placing` a building with a
    /// terrain requirement, every tile of each valid site within `AreaOfEffect.siteSearchRadius` of
    /// `anchor`. Site checks leave materials out, so an island short of them still shows where the
    /// building could stand. Nil for any other kind. Read-only.
    func areaOfEffect(of kind: BuildingKind, at anchor: TileCoordinate, owner: Owner = .player, placing: Bool) -> AreaOfEffect? {
        if let radius = kind.catchmentRadius {
            return catchmentArea(of: kind, at: anchor, radius: radius, owner: owner)
        }
        if placing, let requirement = BuildingCatalog.spec(for: kind).requiredTerrain {
            return siteArea(of: kind, near: anchor, requirement: requirement, owner: owner)
        }
        return nil
    }

    private func catchmentArea(of kind: BuildingKind, at anchor: TileCoordinate, radius: Int, owner: Owner) -> AreaOfEffect {
        let footprint = BuildingCatalog.spec(for: kind).footprint
        let columns = max(0, anchor.x - radius) ... max(0, min(mapWidth - 1, anchor.x + footprint.width - 1 + radius))
        let rows = max(0, anchor.y - radius) ... max(0, min(mapHeight - 1, anchor.y + footprint.height - 1 + radius))
        let tiles = Set(rows.flatMap { y in columns.map { TileCoordinate(x: $0, y: y) } })
        var targets: [TileCoordinate] = []
        visitCatchmentTargets(of: kind, anchor: anchor, owner: owner, tileToIsland: tileToIslandMap()) { targets.append($0) }
        return AreaOfEffect(tiles: tiles, targets: targets, count: targets.count)
    }

    private func siteArea(
        of kind: BuildingKind, near cursor: TileCoordinate, requirement: TerrainRequirement, owner: Owner
    ) -> AreaOfEffect {
        let tileToIsland = tileToIslandMap()
        let footprint = BuildingCatalog.spec(for: kind).footprint
        let isSite = { (anchor: TileCoordinate) in
            self.siteRejection(kind, at: anchor, for: owner, tileToIsland: tileToIsland) == nil
        }
        let reach = AreaOfEffect.siteSearchRadius
        var tiles = Set<TileCoordinate>()
        for y in cursor.y - reach ... cursor.y + reach {
            for x in cursor.x - reach ... cursor.x + reach where isSite(TileCoordinate(x: x, y: y)) {
                tiles.formUnion(footprint.tiles(anchor: TileCoordinate(x: x, y: y)))
            }
        }
        let isRequired = { (tile: TileCoordinate) in self.terrain(at: tile) == requirement.terrain }
        let targets = tiles.filter(isRequired).sorted { ($0.y, $0.x) < ($1.y, $1.x) }
        let count = isSite(cursor) ? footprint.tiles(anchor: cursor).count(where: isRequired) : nil
        return AreaOfEffect(tiles: tiles, targets: targets, count: count)
    }
}
