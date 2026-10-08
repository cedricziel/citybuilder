import Foundation
import SpriteKit
import Testing
@testable import CityCore
@testable import CityRender2D

// Scenarios from openspec/changes/add-culture-signatures.

private let resources = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("Resources")

@Test("scenario: culture signatures are catalogued")
func scenarioCultureSignaturesAreCatalogued() {
    let kinds = BuildingKind.cultureSignatures
    #expect(kinds.map(\.rawValue) == ["mead-hall", "forum", "temple-garden", "caravanserai"])
    let missingEntries = kinds.map { "Sprites.style/catalog/building-\($0.rawValue).md" }.filter {
        !FileManager.default.fileExists(atPath: resources.appendingPathComponent($0).path)
    }
    #expect(missingEntries.isEmpty, "missing catalog entries: \(missingEntries)")
    var sprites: [String] = []
    for kind in kinds {
        let base = "Buildings.atlas/building-\(kind.rawValue)"
        #expect(SpriteAnimation.entry(for: .buildingOperational(kind))?.frameCount == 2)
        sprites += [base] + (0 ..< 3).map { "\(base)-constructing-\($0)" } + (0 ..< 2).map { "\(base)-operational-\($0)" }
    }
    let missingSprites = sprites.filter {
        !FileManager.default.fileExists(atPath: resources.appendingPathComponent("\($0).png").path)
    }
    #expect(missingSprites.isEmpty, "missing sprites: \(missingSprites)")
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

private func house(_ tier: HouseTier, at anchor: TileCoordinate, in world: inout World) -> EntityID {
    let id = inject(.house, at: anchor, in: &world)
    var pop = HousePopulation()
    pop.tier = tier
    pop.population = 4
    world.populations[id] = pop
    return id
}

@MainActor
private func node(for id: EntityID, in world: World) throws -> SKNode {
    let snapshot = world.snapshot()
    let anchor = try #require(snapshot.buildings[id]).anchor
    let spec = try #require(SnapshotReconciler.desiredSprites(
        in: snapshot, xRange: 0 ... snapshot.mapWidth - 1, yRange: 0 ... snapshot.mapHeight - 1
    ).first { spec in
        guard case .building = spec.kind else { return false }
        return spec.coord == anchor
    })
    let scene = IsoWorldScene()
    scene.hasSprite = { _ in true }
    return scene.makeBuildingNode(for: spec)
}

/// The signature look the reconciler gives `id`'s sprite.
private func look(of id: EntityID, in world: World) -> BuildingLook? {
    let snapshot = world.snapshot()
    return snapshot.buildings[id].map { SignatureLooks.look(for: $0, in: snapshot) }
}

// MARK: - Rings and animation

@MainActor
@Test("scenario: temple ring")
func scenarioTempleRing() {
    var world = grass()
    let citizens = house(.citizens, at: TileCoordinate(x: 16, y: 10), in: &world)
    house(.peasants, at: TileCoordinate(x: 10, y: 15), in: &world)
    house(.citizens, at: TileCoordinate(x: 25, y: 10), in: &world)
    let scene = IsoWorldScene()
    scene.ghostProvider = { IsoWorldScene.GhostState(kind: .templeGarden, tile: TileCoordinate(x: 10, y: 10), valid: true) }
    scene.reconcileSignatureRings(with: world.snapshot())
    let rings = scene.children.flatMap(\.children).filter { $0.name == IsoWorldScene.signatureRingNodeName }
    #expect(rings.map { $0.userData?["tiles"] as? Int } == [6])
    #expect(scene.highlightedSignatureTargets == [citizens])
}

@Test("culture signature ring radii")
func cultureSignatureRingRadii() {
    let anchor = TileCoordinate(x: 10, y: 10)
    #expect(SignatureLooks.rings(for: .meadHall, at: anchor).map(\.tiles) == [8])
    #expect(SignatureLooks.rings(for: .forum, at: anchor).map(\.tiles) == [8])
    #expect(SignatureLooks.rings(for: .templeGarden, at: anchor).map(\.tiles) == [6])
    #expect(SignatureLooks.rings(for: .caravanserai, at: anchor).isEmpty)
}

@MainActor
@Test("scenario: unserved forum is idle")
func scenarioUnservedForumIsIdle() throws {
    var world = grass()
    let forum = inject(.forum, at: TileCoordinate(x: 4, y: 4), in: &world)
    let idle = try node(for: forum, in: world)
    #expect(idle.userData?[IsoWorldScene.textureNameKey] as? String == "building-forum")
    #expect(idle.action(forKey: "anim") == nil)
    world.buildings[forum]?.fuelled = true
    #expect(look(of: forum, in: world) == .standard)
}

@MainActor
@Test("an unserved caravanserai is idle and a served one is not")
func caravanseraiAnimatesOnlyWhileServed() throws {
    var world = grass()
    let caravanserai = inject(.caravanserai, at: TileCoordinate(x: 4, y: 4), in: &world)
    #expect(try node(for: caravanserai, in: world).action(forKey: "anim") == nil)
    #expect(look(of: caravanserai, in: world)?.idle == true)
    world.buildings[caravanserai]?.fuelled = true
    #expect(look(of: caravanserai, in: world) == .standard)
}
