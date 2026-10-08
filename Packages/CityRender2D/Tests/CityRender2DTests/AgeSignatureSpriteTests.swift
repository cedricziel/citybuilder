import Foundation
import SpriteKit
import Testing
@testable import CityCore
@testable import CityRender2D

// Scenarios from openspec/changes/add-age-signatures.

private let catalog = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("Resources/Sprites.style/catalog")

@Test("scenario: signature buildings are catalogued")
func scenarioSignatureBuildingsAreCatalogued() {
    let missing = BuildingKind.signatures.map { "building-\($0.rawValue)" }.filter {
        !FileManager.default.fileExists(atPath: catalog.appendingPathComponent("\($0).md").path)
    }
    #expect(BuildingKind.signatures.count == 5)
    #expect(missing.isEmpty, "missing: \(missing)")
}

// MARK: - Fixtures

private func grass() -> World {
    World.fixtureWithTerrain(width: 40, height: 30, fill: .grass, seed: 1)
}

@discardableResult
private func inject(_ kind: BuildingKind, at anchor: TileCoordinate, in world: inout World) -> EntityID {
    let id = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw &+= 1
    world.buildings[id] = Building(id: id, kind: kind, anchor: anchor, state: .operational)
    for tile in BuildingCatalog.spec(for: kind).footprint.tiles(anchor: anchor) {
        world.occupiedTiles[tile] = id
    }
    return id
}

private func buildingSpec(_ id: EntityID, in snapshot: WorldSnapshot) -> SpriteSpec? {
    let anchor = snapshot.buildings[id]?.anchor ?? TileCoordinate(x: 0, y: 0)
    return SnapshotReconciler.desiredSprites(
        in: snapshot, xRange: 0 ... snapshot.mapWidth - 1, yRange: 0 ... snapshot.mapHeight - 1
    ).first { spec in
        guard case .building = spec.kind else { return false }
        return spec.coord == anchor
    }
}

@MainActor
private func node(for id: EntityID, in world: World) throws -> SKNode {
    let scene = IsoWorldScene()
    scene.hasSprite = { _ in true }
    return try scene.makeBuildingNode(for: #require(buildingSpec(id, in: world.snapshot())))
}

// MARK: - Sprites follow their state

@MainActor
@Test("scenario: half-built monument")
func scenarioHalfBuiltMonument() throws {
    var world = grass()
    let monument = inject(.monument, at: TileCoordinate(x: 4, y: 4), in: &world)
    world.buildings[monument]?.projectStages = 12
    let node = try node(for: monument, in: world)
    #expect(node.userData?[IsoWorldScene.textureNameKey] as? String == "building-monument-constructing-1")
    #expect(node.action(forKey: "anim") == nil)
}

@Test("monument stages map to construction frames")
func monumentStagesMapToConstructionFrames() {
    let frames = [0, 8, 9, 16, 17, 24].map { SignatureLooks.projectFrame(stages: UInt8($0)) }
    #expect(frames == [0, 0, 1, 1, 2, 2])
}

@MainActor
@Test("scenario: cold engine is idle")
func scenarioColdEngineIsIdle() throws {
    var world = grass()
    let engine = inject(.steamEngine, at: TileCoordinate(x: 4, y: 4), in: &world)
    let cold = try node(for: engine, in: world)
    #expect(cold.userData?[IsoWorldScene.textureNameKey] as? String == "building-steam-engine")
    #expect(cold.action(forKey: "anim") == nil)
    world.buildings[engine]?.fuelled = true
    let hot = try #require(buildingSpec(engine, in: world.snapshot()))
    guard case let .building(_, _, _, _, _, _, _, _, look) = hot.kind else { return }
    #expect(look == .standard)
}

@MainActor
@Test("smoky houses are tinted grey")
func smokyHousesAreTintedGrey() throws {
    var world = grass()
    let house = inject(.house, at: TileCoordinate(x: 4, y: 4), in: &world)
    let engine = inject(.steamEngine, at: TileCoordinate(x: 8, y: 4), in: &world)
    world.buildings[engine]?.fuelled = true
    let sprite = try #require(try node(for: house, in: world) as? SKSpriteNode)
    #expect(abs(sprite.colorBlendFactor - 0.25) < 0.001)
}

// MARK: - Range rings

@MainActor
@Test("scenario: guild hall ring")
func scenarioGuildHallRing() {
    var world = grass()
    let near = inject(.sawmill, at: TileCoordinate(x: 14, y: 10), in: &world)
    inject(.sawmill, at: TileCoordinate(x: 30, y: 10), in: &world)
    inject(.house, at: TileCoordinate(x: 10, y: 14), in: &world)
    let scene = IsoWorldScene()
    scene.ghostProvider = { IsoWorldScene.GhostState(kind: .guildHall, tile: TileCoordinate(x: 10, y: 10), valid: true) }
    scene.reconcileSignatureRings(with: world.snapshot())
    let rings = scene.children.flatMap(\.children).filter { $0.name == IsoWorldScene.signatureRingNodeName }
    #expect(rings.map { $0.userData?["tiles"] as? Int } == [8])
    #expect(scene.highlightedSignatureTargets == [near])
}

@Test("steam engines draw a speed and a smoke ring, monuments none")
func signatureRingRadii() {
    let anchor = TileCoordinate(x: 10, y: 10)
    #expect(SignatureLooks.rings(for: .steamEngine, at: anchor).map(\.tiles) == [6, 4])
    #expect(SignatureLooks.rings(for: .powerPlant, at: anchor).map(\.tiles) == [10])
    #expect(SignatureLooks.rings(for: .gallery, at: anchor).map(\.tiles) == [8])
    #expect(SignatureLooks.rings(for: .monument, at: anchor).isEmpty)
    let ring = SignatureLooks.rings(for: .guildHall, at: anchor)[0]
    #expect(ring.bounds == TileBoundingBox(minX: 2, minY: 2, maxX: 20, maxY: 20))
}

@MainActor
@Test("a selected signature building shows its ring")
func selectedSignatureBuildingShowsItsRing() {
    var world = grass()
    inject(.gallery, at: TileCoordinate(x: 10, y: 10), in: &world)
    let house = inject(.house, at: TileCoordinate(x: 14, y: 10), in: &world)
    let scene = IsoWorldScene()
    scene.selectionProvider = { TileCoordinate(x: 11, y: 11) }
    scene.reconcileSignatureRings(with: world.snapshot())
    #expect(scene.highlightedSignatureTargets == [house])
    scene.selectionProvider = { nil }
    scene.reconcileSignatureRings(with: world.snapshot())
    #expect(scene.highlightedSignatureTargets.isEmpty)
}
