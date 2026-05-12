import Foundation
import Testing
@testable import CityCore

// Tests for sea-transport scaffolding (M2 of add-archipelago-and-sea).
// Each `#### Scenario:` heading from
// openspec/changes/add-archipelago-and-sea/specs/sea-transport/spec.md
// maps to one `@Test("scenario: <lowercased title>")` here. M2 covers
// only the type-level scaffolding scenarios; the integration / state
// machine / manifest-execution scenarios land in later milestones.

// MARK: - Ship entity (scaffolding)

@Test("scenario: ship has a single canonical position type")
func scenarioShipHasASingleCanonicalPositionType() {
    // The Ship's `position` field MUST be `Fixed2D`; no escape hatch
    // for `Double` or tile-integer positions. Verified at the type
    // level — this test exists so a future field-type drift triggers
    // a unit test rather than only a compile error.
    let ship = Ship(
        id: EntityID(raw: 100),
        position: Fixed2D(x: Fixed(raw: 4096), y: Fixed(raw: 8192)),
        heading: Fixed.zero,
        routeID: nil,
        waypointIdx: 0,
        cargo: [:],
        state: .idle,
        shipClass: .default
    )
    #expect(type(of: ship.position) == Fixed2D.self)
    #expect(type(of: ship.heading) == Fixed.self)
}

@Test("scenario: ship cargo is bounded by capacity")
func scenarioShipCargoIsBoundedByCapacity() {
    let cls = ShipClass.default
    let ship = Ship(
        id: EntityID(raw: 100),
        position: .zero,
        heading: .zero,
        routeID: nil,
        waypointIdx: 0,
        cargo: [.wood: 30, .planks: 20],
        state: .docked,
        shipClass: cls
    )
    let totalCargo = ship.cargo.values.reduce(0, +)
    #expect(totalCargo <= cls.capacity)
}

// MARK: - Snapshot inclusion

@Test("scenario: ship resumes mid-segment after load")
func scenarioShipResumesMidSegmentAfterLoad() throws {
    var world = World.fixtureWithTerrain(width: 8, height: 8, fill: .water, seed: 7)
    let shipID = EntityID(raw: 200)
    let position = Fixed2D(x: Fixed(raw: 12288), y: Fixed(raw: 16384))
    let heading = Fixed(raw: 3217)
    world.ships[shipID] = Ship(
        id: shipID,
        position: position,
        heading: heading,
        routeID: nil,
        waypointIdx: 3,
        cargo: [:],
        state: .sailing,
        shipClass: .default
    )
    let data = try JSONEncoder().encode(world)
    let loaded = try JSONDecoder().decode(World.self, from: data)
    let restored = try #require(loaded.ships[shipID])
    #expect(restored.position == position)
    #expect(restored.heading == heading)
    #expect(restored.waypointIdx == 3)
    #expect(restored.state == .sailing)
}

@Test("scenario: docked ship resumes manifest progress after load")
func scenarioDockedShipResumesManifestProgressAfterLoad() throws {
    var world = World.fixtureWithTerrain(width: 4, height: 4, fill: .water, seed: 1)
    let shipID = EntityID(raw: 300)
    world.ships[shipID] = Ship(
        id: shipID,
        position: .zero,
        heading: .zero,
        routeID: EntityID(raw: 500),
        waypointIdx: 2,
        cargo: [.wood: 15],
        state: .docked,
        shipClass: .default,
        dockedManifestIndex: 1,
        dockedTicksWaited: 42
    )
    let data = try JSONEncoder().encode(world)
    let loaded = try JSONDecoder().decode(World.self, from: data)
    let restored = try #require(loaded.ships[shipID])
    #expect(restored.state == .docked)
    #expect(restored.dockedManifestIndex == 1)
    #expect(restored.dockedTicksWaited == 42)
    #expect(restored.cargo[.wood] == 15)
}

// MARK: - World Codable round-trip with empty ship and route collections

@Test("scenario: world round-trips empty ship and route collections")
func scenarioWorldRoundTripsEmptyShipAndRouteCollections() throws {
    let world = World.fixtureWithTerrain(width: 4, height: 4, fill: .grass, seed: 9)
    let data = try JSONEncoder().encode(world)
    let loaded = try JSONDecoder().decode(World.self, from: data)
    #expect(loaded.ships.isEmpty)
    #expect(loaded.routes.isEmpty)
    #expect(loaded == world)
}
