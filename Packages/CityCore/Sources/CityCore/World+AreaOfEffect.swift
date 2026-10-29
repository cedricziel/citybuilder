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
    public let style: Style

    /// How the area reads: what a building works (gold), what it serves (teal), or what an event
    /// threatens (amber, `add-event-counterplay`).
    public enum Style: Sendable {
        case reach, serves, threat
    }

    public init(tiles: Set<TileCoordinate>, targets: [TileCoordinate], count: Int?, style: Style = .reach) {
        self.tiles = tiles
        self.targets = targets
        self.count = count
        self.style = style
    }
}

public extension World {
    /// The area a `kind` at `anchor` reaches: its catchment, or, while `placing` a building with a
    /// terrain requirement, every tile of each valid site within `AreaOfEffect.siteSearchRadius` of
    /// `anchor`. Site checks leave materials out, so an island short of them still shows where the
    /// building could stand. Nil for any other kind, or for an anchor off the map. Read-only.
    func areaOfEffect(of kind: BuildingKind, at anchor: TileCoordinate, owner: Owner = .player, placing: Bool) -> AreaOfEffect? {
        guard contains(anchor) else { return nil }
        if let radius = kind.catchmentRadius {
            return catchmentArea(of: kind, at: anchor, radius: radius, owner: owner)
        }
        if kind == .fireWatch {
            return fireWatchArea(at: anchor, owner: owner)
        }
        if placing, let requirement = BuildingCatalog.spec(for: kind).requiredTerrain {
            return siteArea(of: kind, near: anchor, requirement: requirement, owner: owner)
        }
        return nil
    }

    /// A fire watch's reach, eight tiles from its footprint, and the flammable buildings of its owner
    /// in it, whose tiles it tints. Spec: `seasonal-events` / A fire watch puts out fires in reach.
    private func fireWatchArea(at anchor: TileCoordinate, owner: Owner) -> AreaOfEffect {
        let reach = Self.fireWatchReach
        let watch = Building(id: EntityID(raw: 0), kind: .fireWatch, anchor: anchor, owner: owner)
        let columns = max(0, anchor.x - reach) ... min(mapWidth - 1, anchor.x + reach)
        let rows = max(0, anchor.y - reach) ... min(mapHeight - 1, anchor.y + reach)
        let tiles = Set(rows.flatMap { y in columns.map { TileCoordinate(x: $0, y: y) } })
        let covered = buildings.values.filter { building in
            building.owner == owner && Self.isFlammable(building.kind) && Self.footprintDistance(watch, building) <= reach
        }
        let targets = covered.flatMap { $0.footprint.tiles(anchor: $0.anchor) }.sorted { ($0.y, $0.x) < ($1.y, $1.x) }
        return AreaOfEffect(tiles: tiles, targets: targets, count: nil, style: .serves)
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
