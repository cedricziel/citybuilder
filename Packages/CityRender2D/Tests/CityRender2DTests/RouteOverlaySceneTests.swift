import CoreImage
import Foundation
import SpriteKit
import Testing
@testable import CityCore
@testable import CityRender2D

// rendering-2_5d scenarios of openspec/changes/add-route-authoring-ui
// (M3), plus the existing "Unselected route does not render polyline"
// and "Ship zRotation always zero", which need a live scene graph.

private func seaSnapshot(ships: [Ship] = [], ticks: Int = 0) -> WorldSnapshot {
    var world = World.fixtureWithTerrain(width: 16, height: 16, fill: .water, seed: 1)
    world.camera = Camera(centerX: 8, centerY: 8, zoom: 1)
    for ship in ships {
        world.ships[ship.id] = ship
    }
    for _ in 0 ..< ticks {
        _ = world.tick()
    }
    return world.snapshot()
}

private func sea(_ x: Int32, _ y: Int32) -> Waypoint {
    .sea(position: Fixed2D(x: Fixed(x), y: Fixed(y)))
}

@MainActor
private func scene(showing overlay: IsoWorldScene.RouteOverlay?) -> IsoWorldScene {
    let scene = IsoWorldScene()
    scene.size = CGSize(width: 1024, height: 768)
    scene.routeOverlayProvider = { overlay }
    return scene
}

/// SpriteKit may hand back the stroke colour in another colour space.
private func isRed(_ colour: SKColor) -> Bool {
    guard let rgba = CIColor(color: colour) else { return false }
    return rgba.red > 0.9 && rgba.green < 0.5 && rgba.blue < 0.5
}

@MainActor
private func nodes(named name: String, in scene: IsoWorldScene) -> [SKNode] {
    scene.routeLayer.children.filter { $0.name == name }
}

@MainActor
@Test("scenario: red leg in the scene")
func scenarioRedLegInTheScene() throws {
    let scene = scene(showing: IsoWorldScene.RouteOverlay(waypoints: [sea(2, 2), sea(6, 2), sea(6, 6)], redSegments: [1]))
    scene.reconcileRoutes(with: seaSnapshot())
    let legs = try nodes(named: RouteLayerNode.legName, in: scene).map { try #require($0 as? SKShapeNode) }
    #expect(legs.count == 2)
    #expect(legs.map { isRed($0.strokeColor) } == [false, true])
    #expect(nodes(named: RouteLayerNode.stopName, in: scene).count == 3)
    #expect(scene.routeLayer.zPosition == RouteLayerZPosition.routes)
}

@MainActor
@Test("scenario: rejected land tap flashes")
func scenarioRejectedLandTapFlashes() {
    var overlay = IsoWorldScene.RouteOverlay(waypoints: [], flash: TileCoordinate(x: 4, y: 5))
    let scene = IsoWorldScene()
    scene.routeOverlayProvider = { overlay }
    scene.reconcileRoutes(with: seaSnapshot())
    let flashes = nodes(named: RouteLayerNode.flashName, in: scene)
    #expect(flashes.count == 1)
    #expect(flashes.first?.position == IsoMath.screenPoint(forTile: TileCoordinate(x: 4, y: 5)))
    overlay = IsoWorldScene.RouteOverlay(waypoints: [])
    scene.reconcileRoutes(with: seaSnapshot())
    #expect(nodes(named: RouteLayerNode.flashName, in: scene).count == 1)
}

@MainActor
@Test("scenario: unselected route does not render polyline")
func scenarioUnselectedRouteDoesNotRenderPolyline() {
    var overlay: IsoWorldScene.RouteOverlay? = IsoWorldScene.RouteOverlay(waypoints: [sea(2, 2), sea(6, 2)])
    let scene = IsoWorldScene()
    scene.routeOverlayProvider = { overlay }
    scene.reconcileRoutes(with: seaSnapshot())
    #expect(nodes(named: RouteLayerNode.legName, in: scene).count == 1)
    overlay = nil
    scene.reconcileRoutes(with: seaSnapshot())
    #expect(nodes(named: RouteLayerNode.legName, in: scene).isEmpty)
    #expect(nodes(named: RouteLayerNode.stopName, in: scene).isEmpty)
}

// MARK: - Ships

private func ship(_ raw: UInt32, x: Int32, y: Int32, heading: Fixed = .zero) -> Ship {
    Ship(
        id: EntityID(raw: raw), position: Fixed2D(x: Fixed(x), y: Fixed(y)), heading: heading,
        routeID: nil, waypointIdx: 0, cargo: [:], state: .sailing, shipClass: .default
    )
}

@MainActor
@Test("scenario: ship zRotation always zero")
func scenarioShipZRotationAlwaysZero() {
    let scene = scene(showing: nil)
    let headings = [Fixed.zero, Fixed(raw: 1638), Fixed(raw: 6434), Fixed(raw: -9000)]
    let ships = headings.enumerated().map { index, heading in ship(UInt32(100 + index), x: 8, y: Int32(6 + index), heading: heading) }
    scene.reconcileShips(with: seaSnapshot(ships: ships))
    #expect(scene.shipLayer.children.count == 4)
    #expect(scene.shipLayer.children.allSatisfy { $0.zRotation == 0 })
}

@MainActor
@Test("the ships layer follows the snapshot and culls far ships")
func shipLayerFollowsSnapshot() {
    let scene = scene(showing: nil)
    scene.reconcileShips(with: seaSnapshot(ships: [ship(100, x: 8, y: 8), ship(101, x: 9, y: 8), ship(102, x: 900, y: 900)]))
    #expect(Set(scene.shipLayer.children.compactMap(\.name)) == ["ship-100", "ship-101"])
    scene.reconcileShips(with: seaSnapshot(ships: [ship(101, x: 9, y: 8)], ticks: 1))
    #expect(scene.shipLayer.children.compactMap(\.name) == ["ship-101"])
}

@MainActor
@Test("a ship's texture follows its heading")
func shipTextureFollowsHeading() {
    let scene = scene(showing: nil)
    scene.reconcileShips(with: seaSnapshot(ships: [ship(100, x: 8, y: 8, heading: .zero)]))
    #expect(scene.shipLayer.textureName(of: EntityID(raw: 100)) == "ship-e-0")
}
