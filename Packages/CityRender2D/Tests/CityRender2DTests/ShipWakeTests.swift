import SpriteKit
import Testing
@testable import CityCore
@testable import CityRender2D

// Scenarios from openspec/changes/add-ship-wake.

private func sea(shipAt x: Int32, tick: Int = 0, zoom: Double = 1) -> WorldSnapshot {
    var world = World.fixtureWithTerrain(width: 16, height: 16, fill: .water, seed: 1)
    world.camera = Camera(centerX: 8, centerY: 8, zoom: zoom)
    let ship = Ship(
        id: EntityID(raw: 100), position: Fixed2D(x: Fixed(x), y: Fixed(8)), heading: .zero,
        routeID: nil, waypointIdx: 0, cargo: [:], state: .sailing, shipClass: .default
    )
    world.ships[ship.id] = ship
    var snapshot = world.snapshot()
    snapshot.tickCount = UInt64(tick)
    return snapshot
}

private let viewSize = CGSize(width: 1024, height: 768)

@MainActor
@Test("scenario: still ship lays none")
func scenarioStillShipLaysNone() throws {
    let layer = ShipLayerNode()
    layer.reconcile(snapshot: sea(shipAt: 8), viewSize: viewSize)
    let wake = try #require(layer.wake(of: EntityID(raw: 100)))
    #expect(wake.particleBirthRate == 0)
}

@MainActor
@Test("scenario: moving ship lays foam")
func scenarioMovingShipLaysFoam() throws {
    let layer = ShipLayerNode()
    layer.reconcile(snapshot: sea(shipAt: 8), viewSize: viewSize)
    layer.reconcile(snapshot: sea(shipAt: 9, tick: 1), viewSize: viewSize)
    let wake = try #require(layer.wake(of: EntityID(raw: 100)))
    #expect(wake.particleBirthRate == ShipWake.birthRate)
    #expect(wake.targetNode === layer.wakeLayer)
    #expect(wake.action(forKey: ShipWake.stopKey) != nil)
    // Heading east (screen down-right): the stern is up-left of the hull.
    #expect(wake.position.x < 0 && wake.position.y > 0)
}

@MainActor
@Test("scenario: reduce motion halves the wake")
func scenarioReduceMotionHalvesTheWake() throws {
    let layer = ShipLayerNode()
    layer.reconcile(snapshot: sea(shipAt: 8), viewSize: viewSize, reduceMotion: true)
    layer.reconcile(snapshot: sea(shipAt: 9, tick: 1), viewSize: viewSize, reduceMotion: true)
    let wake = try #require(layer.wake(of: EntityID(raw: 100)))
    #expect(wake.particleBirthRate == ShipWake.birthRate / 2)
    #expect(wake.particleSpeed == ShipWake.speed / 2)
}

@MainActor
@Test("zoomed out, the foam lives half as long")
func zoomedOutWakeIsShorter() throws {
    let layer = ShipLayerNode()
    layer.reconcile(snapshot: sea(shipAt: 8, zoom: 0.4), viewSize: viewSize)
    layer.reconcile(snapshot: sea(shipAt: 9, tick: 1, zoom: 0.4), viewSize: viewSize)
    let wake = try #require(layer.wake(of: EntityID(raw: 100)))
    #expect(wake.particleLifetime == ShipWake.lifetime / 2)
}

@MainActor
@Test("the scene puts the wake layer under the buildings")
func wakeLayerSitsUnderBuildings() {
    let scene = IsoWorldScene()
    scene.size = viewSize
    scene.reconcileShips(with: sea(shipAt: 8))
    #expect(scene.shipLayer.wakeLayer.parent === scene)
    #expect(scene.shipLayer.wakeLayer.zPosition > 0 && scene.shipLayer.wakeLayer.zPosition < 10)
}
