import Foundation
import Testing
@testable import CityCore

// Tests for the applyPlace partial-deduction + waiting-state flow
// added by `add-construction-stalls` → M3.

private func injectOperational(
    in world: inout World,
    kind: BuildingKind,
    at anchor: TileCoordinate
) -> EntityID {
    let id = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw &+= 1
    let footprint = BuildingCatalog.spec(for: kind).footprint
    world.buildings[id] = Building(
        id: id,
        kind: kind,
        anchor: anchor,
        state: .operational,
        ticksSincePlacement: 0
    )
    for tile in footprint.tiles(anchor: anchor) {
        world.occupiedTiles[tile] = id
    }
    return id
}

private func resetTownCenter(in world: inout World, contents: [Good: Int]) {
    for (id, building) in world.buildings where building.kind == .townCenter {
        var stockpile = Stockpile(capacity: 8)
        for (good, amount) in contents {
            _ = stockpile.deposit(good, amount: amount)
        }
        world.stockpiles[id] = stockpile
    }
}

private func firstFreeGrassAnchor2x2(in world: World) -> TileCoordinate? {
    for tileY in 0 ..< world.mapHeight - 1 {
        for tileX in 0 ..< world.mapWidth - 1 {
            let anchor = TileCoordinate(x: tileX, y: tileY)
            var ok = true
            for deltaY in 0 ... 1 where ok {
                for deltaX in 0 ... 1 where ok {
                    let tile = TileCoordinate(x: tileX + deltaX, y: tileY + deltaY)
                    let terrainHere = world.terrain(at: tile) ?? .water
                    if terrainHere != .grass, terrainHere != .forest { ok = false }
                    if world.occupiedTiles[tile] != nil { ok = false }
                }
            }
            if ok { return anchor }
        }
    }
    return nil
}

@Test("scenario: applyplace deducts all available and seeds materialsdelivered")
func scenarioApplyPlaceDeductsAllAvailableAndSeedsMaterialsDelivered() throws {
    var world = World.newGame()
    world.economy.credit(100_000)
    // Town center has 4 wood + 2 planks at world-gen. Sawmill costs
    // 4 wood + 1 plank. Drop town center to 2 wood + 1 plank so the
    // placement can deduct what's there and queue on the wood deficit.
    resetTownCenter(in: &world, contents: [.wood: 2, .planks: 1])
    // Plant a lumberjack so the wood deficit becomes queueable.
    let anchor = try #require(firstFreeGrassAnchor2x2(in: world))
    _ = injectOperational(in: &world, kind: .lumberjackHut, at: anchor)
    let sawmillAnchor = TileCoordinate(x: anchor.x, y: anchor.y + 4)
    world.pendingCommands.append(.place(.sawmill, at: sawmillAnchor))
    _ = world.tick()
    let placed = world.buildings.values.first { $0.kind == .sawmill && $0.anchor == sawmillAnchor }
    let sawmill = try #require(placed)
    #expect(sawmill.materialsDelivered[.wood] == 2)
    #expect(sawmill.materialsDelivered[.planks] == 1)
}

@Test("scenario: applyplace marks building waitingformaterials when partially supplied")
func scenarioApplyPlaceMarksBuildingWaitingForMaterialsWhenPartiallySupplied() throws {
    var world = World.newGame()
    world.economy.credit(100_000)
    resetTownCenter(in: &world, contents: [.wood: 2, .planks: 1])
    let anchor = try #require(firstFreeGrassAnchor2x2(in: world))
    _ = injectOperational(in: &world, kind: .lumberjackHut, at: anchor)
    let sawmillAnchor = TileCoordinate(x: anchor.x, y: anchor.y + 4)
    world.pendingCommands.append(.place(.sawmill, at: sawmillAnchor))
    _ = world.tick()
    let placed = world.buildings.values.first { $0.kind == .sawmill && $0.anchor == sawmillAnchor }
    let sawmill = try #require(placed)
    #expect(sawmill.constructionState == .waitingForMaterials)
}

@Test("scenario: applyplace marks building actively when fully supplied")
func scenarioApplyPlaceMarksBuildingActivelyWhenFullySupplied() throws {
    var world = World.newGame()
    world.economy.credit(100_000)
    // Town center starter is 6 wood + 4 planks; lumberjack costs 2 wood.
    let anchor = try #require(firstFreeGrassAnchor2x2(in: world))
    world.pendingCommands.append(.place(.lumberjackHut, at: anchor))
    _ = world.tick()
    let placed = world.buildings.values.first { $0.kind == .lumberjackHut && $0.anchor == anchor }
    let lumberjack = try #require(placed)
    #expect(lumberjack.constructionState == .actively)
    #expect(lumberjack.materialsDelivered[.wood] == 2)
}

@Test("scenario: applyplace emits constructionwaitingformaterials when partial")
func scenarioApplyPlaceEmitsConstructionWaitingForMaterialsWhenPartial() throws {
    var world = World.newGame()
    world.economy.credit(100_000)
    resetTownCenter(in: &world, contents: [.wood: 2, .planks: 1])
    let anchor = try #require(firstFreeGrassAnchor2x2(in: world))
    _ = injectOperational(in: &world, kind: .lumberjackHut, at: anchor)
    let sawmillAnchor = TileCoordinate(x: anchor.x, y: anchor.y + 4)
    world.pendingCommands.append(.place(.sawmill, at: sawmillAnchor))
    let result = world.tick()
    let waitingEvent = result.events.first { event in
        if case .constructionWaitingForMaterials = event { return true }
        return false
    }
    let waiting = try #require(waitingEvent)
    if case let .constructionWaitingForMaterials(_, missing) = waiting {
        #expect(missing[.wood] == 2)
    } else {
        Issue.record("unexpected event shape")
    }
}

@Test("scenario: constructionwaitingformaterials emitted on partial placement")
func scenarioConstructionWaitingForMaterialsEmittedOnPartialPlacement() throws {
    var world = World.newGame()
    world.economy.credit(100_000)
    resetTownCenter(in: &world, contents: [.wood: 2, .planks: 1])
    let anchor = try #require(firstFreeGrassAnchor2x2(in: world))
    _ = injectOperational(in: &world, kind: .lumberjackHut, at: anchor)
    let sawmillAnchor = TileCoordinate(x: anchor.x, y: anchor.y + 4)
    world.pendingCommands.append(.place(.sawmill, at: sawmillAnchor))
    let result = world.tick()
    let waitingEvents = result.events.filter {
        if case .constructionWaitingForMaterials = $0 { return true }
        return false
    }
    #expect(waitingEvents.count == 1)
}

@Test("scenario: neither event emitted for instant-deduct placement")
func scenarioNeitherEventEmittedForInstantDeductPlacement() throws {
    var world = World.newGame()
    world.economy.credit(100_000)
    let anchor = try #require(firstFreeGrassAnchor2x2(in: world))
    world.pendingCommands.append(.place(.lumberjackHut, at: anchor))
    let result = world.tick()
    let hasWaiting = result.events.contains { event in
        if case .constructionWaitingForMaterials = event { return true }
        return false
    }
    let hasStarted = result.events.contains { event in
        if case .constructionStarted = event { return true }
        return false
    }
    let hasMaterialsDeducted = result.events.contains { event in
        if case .materialsDeducted = event { return true }
        return false
    }
    #expect(!hasWaiting)
    #expect(!hasStarted)
    #expect(hasMaterialsDeducted)
}
