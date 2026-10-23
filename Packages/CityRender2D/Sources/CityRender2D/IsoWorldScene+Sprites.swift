import CityCore
import SpriteKit

/// Everything the building sprites on screen were drawn from: a snapshot field that
/// `SnapshotReconciler.buildingSprites` reads belongs here too. A frame with the same inputs keeps
/// the sprites; the snapshot shares most of these collections' storage with the world, so the check
/// is cheap while nothing changes.
struct BuildingSpriteInputs: Equatable {
    let xRange: ClosedRange<Int>
    let yRange: ClosedRange<Int>
    let buildings: [EntityID: Building]
    let occupiedTiles: [TileCoordinate: EntityID]
    let roadDisconnectedBuildings: Set<EntityID>
    let housePopulations: [EntityID: HousePopulation]
    let houseModifiers: [EntityID: HouseModifiers]
    let rivals: [RivalSummary]

    init(_ snapshot: WorldSnapshot, view: VisibleTiles) {
        xRange = view.xRange
        yRange = view.yRange
        buildings = snapshot.buildings
        occupiedTiles = snapshot.occupiedTiles
        roadDisconnectedBuildings = snapshot.roadDisconnectedBuildings
        housePopulations = snapshot.housePopulations
        houseModifiers = snapshot.houseModifiers
        rivals = snapshot.rivals
    }
}

/// How much work the sprite reconcile has done, so tests can pin it to the frames that change
/// something.
struct SpriteReconcileCounts: Equatable {
    var terrainPasses = 0
    var buildingPasses = 0
    var tilesAdded = 0
    var tilesRemoved = 0
}

extension IsoWorldScene {
    /// Brings the terrain and building sprites in line with the snapshot. A frame with the same view,
    /// terrain and buildings as the last does nothing; a pan adds and removes only the tiles at the
    /// edges. Spec: `rendering-2_5d` / Snapshot-driven rendering.
    func reconcileSprites(with snapshot: WorldSnapshot) {
        guard let view = VisibleTiles(
            camera: snapshot.camera, viewSize: size, mapWidth: snapshot.mapWidth, mapHeight: snapshot.mapHeight
        )
        else { return }
        reconcileTerrain(in: view, with: snapshot)
        reconcileBuildings(in: view, with: snapshot)
    }

    private func reconcileTerrain(in view: VisibleTiles, with snapshot: WorldSnapshot) {
        let (width, height, grid) = (snapshot.mapWidth, snapshot.mapHeight, snapshot.terrainGrid)
        var redrawAll = false
        if transitionMap?.matches(width: width, height: height, grid: grid) != true {
            transitionMap = TerrainTransitionMap(width: width, height: height, grid: grid)
            redrawAll = true
        }
        if objectMap?.matches(width: width, height: height, grid: grid) == true {
            staleTerrain.formUnion(objectMap?.update(occupancy: snapshot.occupiedTiles) ?? [])
        } else {
            objectMap = TerrainObjectMap(width: width, height: height, grid: grid, occupancy: snapshot.occupiedTiles)
            redrawAll = true
        }
        if redrawAll, let transitionMap {
            showDeepWater(DeepWaterMask(width: width, height: height, grid: grid, transitions: transitionMap))
        }
        guard redrawAll || view != shownTiles || !staleTerrain.isEmpty else { return }
        spriteReconcileCounts.terrainPasses += 1
        for coord in shownTiles?.tiles(notIn: view) ?? [] {
            removeTerrain(at: coord)
        }
        for coord in redrawAll ? view.tiles : view.tiles(notIn: shownTiles) {
            drawTerrain(at: coord, in: snapshot)
        }
        for coord in staleTerrain where !redrawAll && view.contains(coord) {
            drawTerrain(at: coord, in: snapshot)
        }
        shownTiles = view
        staleTerrain.removeAll()
    }

    /// Places the tile's terrain sprite, replacing the one there when it differs. Open water has no
    /// sprite of its own: the deep-water tile map draws it.
    private func drawTerrain(at coord: TileCoordinate, in snapshot: WorldSnapshot) {
        guard deepWaterMask?.contains(coord) != true else {
            removeTerrain(at: coord)
            return
        }
        guard let spec = SnapshotReconciler.terrainSprite(at: coord, in: snapshot, transitions: transitionMap, objects: objectMap),
              spec != terrainSpecs[coord]
        else { return }
        removeTerrain(at: coord)
        place(spec)
        terrainSpecs[coord] = spec
        spriteReconcileCounts.tilesAdded += 1
    }

    func removeTerrain(at coord: TileCoordinate) {
        guard let spec = terrainSpecs.removeValue(forKey: coord) else { return }
        presentSprites.removeValue(forKey: spec)?.removeFromParent()
        spriteReconcileCounts.tilesRemoved += 1
    }

    private func reconcileBuildings(in view: VisibleTiles, with snapshot: WorldSnapshot) {
        let inputs = BuildingSpriteInputs(snapshot, view: view)
        guard inputs != shownBuildingInputs else { return }
        shownBuildingInputs = inputs
        spriteReconcileCounts.buildingPasses += 1
        let desired = SnapshotReconciler.buildingSprites(
            in: snapshot, xRange: view.xRange, yRange: view.yRange, roadLinks: roadLinkCache.links(for: snapshot)
        )
        for spec in buildingSpecs.subtracting(desired) {
            guard let node = presentSprites.removeValue(forKey: spec) else { continue }
            node.removeFromParent()
            if buildingNodes[spec.coord] === node { buildingNodes.removeValue(forKey: spec.coord) }
        }
        for spec in desired.subtracting(buildingSpecs) {
            if let sprite = place(spec) as? SKSpriteNode { buildingNodes[spec.coord] = sprite }
        }
        buildingSpecs = desired
    }

    @discardableResult
    private func place(_ spec: SpriteSpec) -> SKNode {
        let node = placedNode(for: spec)
        addChild(node)
        presentSprites[spec] = node
        return node
    }
}
