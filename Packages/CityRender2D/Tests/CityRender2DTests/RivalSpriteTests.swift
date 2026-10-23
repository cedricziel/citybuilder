import Foundation
import SpriteKit
import Testing
@testable import CityCore
@testable import CityRender2D

// rendering-2_5d scenarios of openspec/changes/add-rival-towns (M5).

/// A Northern European Hard archipelago: rival 1 is Mediterranean and
/// crimson, rival 2 East Asian.
private func rivalWorld() -> World {
    World.newGame(layout: .archipelago, seed: 0, culture: .northernEuropean, difficulty: .hard)
}

/// The scene node for the building standing on `tile`.
@MainActor
private func node(at tile: TileCoordinate, in world: World) throws -> SKNode {
    let snapshot = world.snapshot()
    let spec = try #require(SnapshotReconciler.desiredSprites(
        in: snapshot, xRange: tile.x ... tile.x, yRange: tile.y ... tile.y
    ).first { if case .building = $0.kind { true } else { false } })
    let scene = IsoWorldScene()
    scene.culture = snapshot.culture
    scene.age = snapshot.age
    scene.hasSprite = { _ in true }
    return scene.makeBuildingNode(for: spec)
}

@MainActor
private func textureName(_ node: SKNode) -> String? {
    node.userData?[IsoWorldScene.textureNameKey] as? String
}

@MainActor
private func pennant(_ node: SKNode) -> SKNode? {
    node.childNode(withName: IsoWorldScene.pennantNodeName)
}

/// Adds an operational building of `owner` at `anchor`.
private func add(_ kind: BuildingKind, at anchor: TileCoordinate, owner: Owner, to world: inout World) {
    let id = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw &+= 1
    world.buildings[id] = Building(id: id, kind: kind, anchor: anchor, state: .operational, owner: owner)
    for tile in BuildingCatalog.spec(for: kind).footprint.tiles(anchor: anchor) {
        world.occupiedTiles[tile] = id
    }
}

// MARK: - Buildings render in their owner's culture

@MainActor
@Test("scenario: rival town center in its own culture")
func scenarioRivalTownCenterInItsOwnCulture() throws {
    let world = rivalWorld()
    let center = try #require(world.buildings[world.rivals[1].townCenterID])
    #expect(world.rivals[1].culture == .eastAsian)
    #expect(try textureName(node(at: center.anchor, in: world)) == "building-town-center-east-asian")
}

@MainActor
@Test("scenario: player buildings unchanged")
func scenarioPlayerBuildingsUnchanged() throws {
    let world = rivalWorld()
    let center = try #require(world.buildings.values.first { $0.kind == .townCenter && $0.owner == .player })
    let playerNode = try node(at: center.anchor, in: world)
    #expect(textureName(playerNode) == nil)
    #expect(pennant(playerNode) == nil)
}

// MARK: - Rival buildings fly a pennant

@MainActor
@Test("scenario: pennant on a rival house")
func scenarioPennantOnARivalHouse() throws {
    var world = rivalWorld()
    let anchor = TileCoordinate(x: 2, y: 2)
    add(.house, at: anchor, owner: .rival(1), to: &world)
    let flag = try #require(pennant(node(at: anchor, in: world)))
    #expect(flag.userData?[IsoWorldScene.pennantColourKey] as? String == "#B03A2E")
    #expect(flag.zPosition > 0)
}

@MainActor
@Test("scenario: no pennant on roads or player buildings")
func scenarioNoPennantOnRoadsOrPlayerBuildings() throws {
    var world = rivalWorld()
    let road = TileCoordinate(x: 2, y: 2)
    let house = TileCoordinate(x: 6, y: 2)
    add(.road, at: road, owner: .rival(1), to: &world)
    add(.house, at: house, owner: .player, to: &world)
    #expect(try pennant(node(at: road, in: world)) == nil)
    #expect(try pennant(node(at: house, in: world)) == nil)
}

@MainActor
@Test("a rival site under construction flies a pennant too")
func rivalConstructionSiteFliesAPennant() throws {
    var world = rivalWorld()
    let anchor = TileCoordinate(x: 2, y: 2)
    add(.house, at: anchor, owner: .rival(2), to: &world)
    let id = try #require(world.occupiedTiles[anchor])
    world.buildings[id]?.state = .constructing
    let flag = try #require(pennant(node(at: anchor, in: world)))
    #expect(flag.userData?[IsoWorldScene.pennantColourKey] as? String == "#2E6DB4")
}

@MainActor
@Test("pennant texture is drawn once per colour")
func pennantTextureIsCachedPerColour() {
    let crimson = IsoWorldScene.pennantTexture(colourHex: "#B03A2E")
    #expect(IsoWorldScene.pennantTexture(colourHex: "#B03A2E") === crimson)
    #expect(IsoWorldScene.pennantTexture(colourHex: "#2E6DB4") !== crimson)
    #expect(crimson.size() == CGSize(width: 6, height: 6))
}

/// A sprite is wider than its footprint where its shadow needs the room; the pennant stays over the
/// footprint's left corner.
@MainActor
@Test("a rival's pennant sits over its footprint, not the sprite's shadow margin")
func pennantSitsOverTheFootprint() {
    let wide = SKSpriteNode(color: .clear, size: CGSize(width: 224, height: 200))
    let pennant = IsoWorldScene.makePennantNode(colourHex: "#c03030", on: wide, footprint: Footprint(width: 2, height: 2))
    #expect(pennant.position == CGPoint(x: -64, y: 200))
    let narrow = SKSpriteNode(color: .clear, size: CGSize(width: 96, height: 120))
    #expect(IsoWorldScene.makePennantNode(colourHex: "#c03030", on: narrow, footprint: Footprint(width: 2, height: 2)).position.x == -48)
}
