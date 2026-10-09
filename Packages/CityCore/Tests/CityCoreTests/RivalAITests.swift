import Foundation
import Testing
@testable import CityCore

// rival-towns AI scenarios (openspec/changes/add-rival-towns, M2):
// command queue, build order, town plan and ages.

private func normalWorld() -> World {
    World.newGame(layout: .archipelago, seed: 0, difficulty: .normal)
}

private func anchor(_ command: Command) -> TileCoordinate? {
    if case let .rivalPlace(_, _, anchor) = command { anchor } else { nil }
}

// MARK: - Rival turns go through the command queue

@Test("scenario: commands apply on the next tick")
func scenarioCommandsApplyOnTheNextTick() throws {
    var world = normalWorld()
    _ = world.testRun(ticks: 49)
    #expect(world.pendingCommands.isEmpty)
    world.tick()
    let commands = world.pendingCommands
    #expect(commands.allSatisfy { if case .rivalPlace(1, _, _) = $0 { true } else { false } })
    #expect(placedKind(commands.last) == .lumberjackHut)
    let hutAnchor = try #require(commands.last.flatMap(anchor))
    world.tick()
    let hut = try #require(world.occupiedTiles[hutAnchor].flatMap { world.buildings[$0] })
    #expect(hut.kind == .lumberjackHut)
    #expect(hut.owner == .rival(1))
}

@Test("scenario: turn leaves the rng alone")
func scenarioTurnLeavesTheRngAlone() {
    var world = normalWorld()
    let rng = world.rng
    let commands = world.takeTurn(1)
    #expect(!commands.isEmpty)
    #expect(world.rng == rng)
}

@Test("scenario: rejected rival command is silent")
func scenarioRejectedRivalCommandIsSilent() throws {
    var world = normalWorld()
    let rival = try #require(world.rival(1))
    let occupied = try #require(world.buildings[rival.townCenterID]).anchor
    let count = world.buildings.count
    world.enqueue(.rivalPlace(1, .house, at: occupied))
    let events = world.tick().events
    #expect(world.buildings.count == count)
    #expect(!events.contains { if case .placementRejected = $0 { true } else { false } })
}

// MARK: - Rival build order

@Test("rivals build only their kit, never a signature building")
func rivalsBuildOnlyTheirKit() {
    let scripted = (0 ..< RivalAI.opening.count + RivalAI.growthLoop.count).map(RivalAI.scriptKind(at:))
    let thresholds: [BuildingKind] = [.farm, .sawmill, .lumberjackHut]
    let kit: Set<BuildingKind> = [.house, .road, .lumberjackHut, .sawmill, .farm, .warehouse]
    #expect(Set(scripted + thresholds).isSubset(of: kit))
    #expect(kit.allSatisfy { $0.signatureReaches.isEmpty && $0.culture == nil })
}

@Test("scenario: opening step")
func scenarioOpeningStep() {
    var world = normalWorld()
    world.setRivalStock(1, [.wood: 6, .planks: 5, .food: 2])
    let commands = world.takeTurn(1)
    #expect(placedKind(commands.last) == .lumberjackHut)
    #expect(world.rival(1)?.ai.scriptIndex == 1)
}

@Test("scenario: food threshold overrides the script")
func scenarioFoodThresholdOverridesTheScript() {
    var world = normalWorld()
    world.setRival(1) { $0.ai.scriptIndex = 12 }
    world.setRivalStock(1, [.wood: 20, .planks: 10, .food: 3])
    for _ in 0 ..< 4 {
        world.testAddBuilding(.house, owner: .rival(1))
    }
    world.testAddBuilding(.farm, owner: .rival(1))
    world.testAddBuilding(.lumberjackHut, owner: .rival(1))
    world.testAddBuilding(.lumberjackHut, owner: .rival(1))
    world.testAddBuilding(.sawmill, owner: .rival(1))
    let commands = world.takeTurn(1)
    #expect(placedKind(commands.last) == .farm)
    #expect(world.rival(1)?.ai.scriptIndex == 12)
}

@Test("a threshold rule the rival can't carry out gives way to the next")
func unsuppliedThresholdGivesWayToTheNext() {
    var world = normalWorld()
    world.setRival(1) { $0.ai.scriptIndex = 12 }
    // One house asks for a farm, but there is no wood for it and no
    // forest left to cut; a hut needs no wood from a rival.
    world.setRivalStock(1, [.planks: 10, .food: 0])
    world.testAddBuilding(.house, owner: .rival(1))
    world.testAddBuilding(.sawmill, owner: .rival(1))
    let commands = world.takeTurn(1)
    #expect(placedKind(commands.last) == .lumberjackHut)
    #expect(world.rival(1)?.ai.scriptIndex == 12)
}

@Test("a rival's lumberjack hut costs no wood")
func rivalHutCostsNoWood() throws {
    var world = normalWorld()
    world.setRivalStock(1, [:])
    let commands = world.takeTurn(1)
    #expect(placedKind(commands.last) == .lumberjackHut)
    world.tick()
    let anchor = try #require(commands.last.flatMap(anchor))
    let hut = try #require(world.occupiedTiles[anchor].flatMap { world.buildings[$0] })
    #expect(hut.constructionState == .actively)
    #expect(world.materialCost(of: .lumberjackHut, for: .player) == [.wood: 2])
}

@Test("scenario: waiting for money")
func scenarioWaitingForMoney() {
    var world = normalWorld()
    world.setRival(1) {
        $0.treasury = 40
        $0.ai.scriptIndex = 3
    }
    let commands = world.takeTurn(1)
    #expect(commands.isEmpty)
    #expect(world.rival(1)?.ai.waitTurns == 1)
    #expect(world.rival(1)?.ai.scriptIndex == 3)
}

@Test("scenario: skipping a stuck step")
func scenarioSkippingAStuckStep() {
    var world = normalWorld()
    world.setRival(1) { $0.treasury = 40 }
    for _ in 0 ..< 9 {
        _ = world.takeTurn(1)
    }
    #expect(world.rival(1)?.ai.waitTurns == 9)
    #expect(world.rival(1)?.ai.scriptIndex == 0)
    _ = world.takeTurn(1)
    #expect(world.rival(1)?.ai.scriptIndex == 1)
    #expect(world.rival(1)?.ai.waitTurns == 0)
}

@Test("scenario: house cap")
func scenarioHouseCap() {
    var world = normalWorld()
    world.setRival(1) { $0.ai.scriptIndex = 18 }
    world.setRivalStock(1, [.wood: 14, .planks: 12, .food: 10])
    for _ in 0 ..< 30 {
        world.testAddBuilding(.house, owner: .rival(1))
    }
    for _ in 0 ..< 4 {
        world.testAddBuilding(.farm, owner: .rival(1))
    }
    // A port already stands, so the port rule (add-rival-trade) is quiet.
    world.testAddBuilding(.port, owner: .rival(1))
    let commands = world.takeTurn(1)
    #expect(placedKind(commands.last) == .sawmill)
    #expect(world.rival(1)?.ai.scriptIndex == 12)
}

@Test("rival takes no step at 50 buildings")
func rivalTakesNoStepAtTheBuildingCap() {
    var world = normalWorld()
    for _ in 0 ..< 49 {
        world.testAddBuilding(.farm, owner: .rival(1))
    }
    #expect(world.takeTurn(1).isEmpty)
    #expect(world.rival(1)?.ai.waitTurns == 0)
}

// MARK: - Rival town plan

@Test("scenario: first building opens the home block")
func scenarioFirstBuildingOpensTheHomeBlock() throws {
    var world = normalWorld()
    let rival = try #require(world.rival(1))
    let center = try #require(world.buildings[rival.townCenterID]).anchor
    let commands = world.takeTurn(1)
    var ring: [TileCoordinate] = []
    for y in center.y - 1 ... center.y + 4 {
        for x in center.x - 1 ... center.x + 4 {
            let onRing = y == center.y - 1 || y == center.y + 4 || x == center.x - 1 || x == center.x + 4
            if onRing { ring.append(TileCoordinate(x: x, y: y)) }
        }
    }
    #expect(ring.count == 20)
    #expect(commands.prefix(20).map { anchor($0) } == ring)
    #expect(commands.prefix(20).allSatisfy { placedKind($0) == .road })
    let building = try #require(commands.last.flatMap(anchor))
    let blockX = (building.x - center.x).floorDiv(5)
    let blockY = (building.y - center.y).floorDiv(5)
    #expect(max(abs(blockX), abs(blockY)) == 1)
}

@Test("scenario: rival buildings touch a road")
func scenarioRivalBuildingsTouchARoad() throws {
    var world = World.newGame(layout: .archipelago, seed: 0, difficulty: .hard)
    world.setRival(1) { $0.treasury = 100_000 }
    var steps = 0
    // Bounded: one turn per 30 ticks, at most 60 turns.
    for _ in 0 ..< 60 where steps < 20 {
        world.setRivalStock(1, [.wood: 20, .planks: 20, .food: 20])
        let before = world.rival(1)?.ai.scriptIndex
        _ = world.testRun(ticks: 30)
        if world.rival(1)?.ai.scriptIndex != before { steps += 1 }
    }
    #expect(steps >= 20)
    _ = world.testRun(ticks: 2)
    let rival = try #require(world.rival(1))
    let center = try #require(world.buildings[rival.townCenterID])
    let centerFootprint = BuildingCatalog.spec(for: .townCenter).footprint
    let rivalBuildings = world.buildings.values.filter { $0.owner == .rival(1) && $0.kind != .road }
    #expect(rivalBuildings.count > 10)
    // The port needs no road (add-rival-trade D1).
    for building in rivalBuildings where building.id != center.id && building.kind != .port {
        let footprint = BuildingCatalog.spec(for: building.kind).footprint
        #expect(
            world.sharesRoadNetwork(building.anchor, footprint, with: center.anchor, centerFootprint),
            "\(building.kind) at \(building.anchor) is not on the town's roads"
        )
    }
}

// MARK: - Rival ages

@Test("scenario: rival enters the middle ages")
func scenarioRivalEntersTheMiddleAges() {
    var world = World.newGame(layout: .archipelago, seed: 0, age: .antiquity, difficulty: .normal)
    world.testAddResidents(24, owner: .rival(1))
    _ = world.testRun(ticks: 49)
    let events = world.tick().events
    #expect(world.rival(1)?.age == .medieval)
    #expect(events.contains(.rivalAgeAdvanced(1, .medieval)))
}

@Test("scenario: one age per turn")
func scenarioOneAgePerTurn() {
    var world = World.newGame(layout: .archipelago, seed: 0, age: .antiquity, difficulty: .normal)
    world.testAddResidents(70, owner: .rival(1))
    var events: [WorldEvent] = []
    world.runRivalTurn(1, events: &events)
    #expect(world.rival(1)?.age == .medieval)
    #expect(events == [.rivalAgeAdvanced(1, .medieval)])
}

private extension Int {
    func floorDiv(_ divisor: Int) -> Int {
        (self >= 0 ? self : self - divisor + 1) / divisor
    }
}
