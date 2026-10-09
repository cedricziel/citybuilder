import Foundation
import Testing
@testable import CityCore
@testable import CityUI

// platform-shells scenarios of openspec/changes/add-rival-trade (M3).

/// A Normal archipelago where rival 1 owns a port and a warehouse
/// holding `stock`; its town center is emptied so the warehouse is the
/// rival's whole stock.
private func marketWorld(stock: [Good: Int]) throws -> (world: World, port: EntityID) {
    var world = World.newGame(layout: .archipelago, seed: 0, difficulty: .normal)
    let rival = try #require(world.rival(1))
    world.stockpiles[rival.townCenterID] = Stockpile(capacity: 40)
    let warehouse = add(.warehouse, owner: rival.owner, at: TileCoordinate(x: -10, y: -10), to: &world)
    var pile = Stockpile(capacity: 200)
    for good in Good.allCases {
        if let amount = stock[good] { pile.deposit(good, amount: amount) }
    }
    world.stockpiles[warehouse] = pile
    let port = add(.port, owner: rival.owner, at: TileCoordinate(x: 2, y: 2), to: &world)
    return (world, port)
}

/// Inserts an operational building and marks its footprint occupied.
private func add(_ kind: BuildingKind, owner: Owner, at anchor: TileCoordinate, to world: inout World) -> EntityID {
    let id = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw &+= 1
    world.buildings[id] = Building(id: id, kind: kind, anchor: anchor, state: .operational, owner: owner)
    for tile in BuildingCatalog.spec(for: kind).footprint.tiles(anchor: anchor) {
        world.occupiedTiles[tile] = id
    }
    if let capacity = World.stockpileCapacity(for: kind) {
        world.stockpiles[id] = Stockpile(capacity: capacity)
    }
    return id
}

// MARK: - Rival market in the inspector

@Test("scenario: market rows")
func scenarioMarketRows() throws {
    let (world, port) = try marketWorld(stock: [.wood: 42])
    let snapshot = world.snapshot()
    let anchor = try #require(world.buildings[port]).anchor
    let market = try #require(InspectorViewModel.make(from: snapshot, tile: anchor, buildings: snapshot.buildings).market)
    #expect(market.sells == ["Wood — $5 — 12 available"])
    #expect(market.buys.contains("Tools — $22 — wants 20"))
    #expect(!market.buys.contains { $0.hasPrefix("Wood") })
}

@Test("an empty market reads nothing for sale")
func emptyMarketRows() throws {
    let (world, port) = try marketWorld(stock: [.wood: 25, .planks: 25, .food: 25, .bread: 25, .tools: 25])
    let snapshot = world.snapshot()
    let anchor = try #require(world.buildings[port]).anchor
    let market = try #require(InspectorViewModel.make(from: snapshot, tile: anchor, buildings: snapshot.buildings).market)
    #expect(market.sells == ["Nothing for sale"])
    #expect(market.buys == ["Buying nothing"])
}

@Test("only a rival's port has a market")
func onlyRivalPortsHaveAMarket() throws {
    var (world, _) = try marketWorld(stock: [.wood: 42])
    let playerPort = add(.port, owner: .player, at: TileCoordinate(x: 6, y: 2), to: &world)
    let snapshot = world.snapshot()
    let anchor = try #require(world.buildings[playerPort]).anchor
    #expect(InspectorViewModel.make(from: snapshot, tile: anchor, buildings: snapshot.buildings).market == nil)
}

// MARK: - Buy and Sell in the manifest editor

@Test("scenario: buy label and price")
func scenarioBuyLabelAndPrice() throws {
    let (world, port) = try marketWorld(stock: [.wood: 42])
    let editor = ManifestEditorModel(snapshot: world.snapshot(), port: port)
    #expect(editor.label(for: .load) == "Buy")
    #expect(editor.label(for: .unload) == "Sell")
    let wood = try #require(editor.rows(for: .load).first { $0.good == .wood })
    #expect(wood.price == "$5")
    #expect(wood.offer == "12")
    let iron = try #require(editor.rows(for: .load).first { $0.good == .iron })
    #expect(iron.price == nil)
    #expect(iron.offer == "no offer")
    let tools = try #require(editor.rows(for: .unload).first { $0.good == .tools })
    #expect(tools.price == "$22")
    #expect(tools.offer == "20")
}

@Test("a player port's manifest reads load and unload without prices")
func playerPortManifestLabels() throws {
    var (world, _) = try marketWorld(stock: [:])
    let playerPort = add(.port, owner: .player, at: TileCoordinate(x: 6, y: 2), to: &world)
    let editor = ManifestEditorModel(snapshot: world.snapshot(), port: playerPort)
    #expect(editor.label(for: .load) == "Load")
    #expect(editor.label(for: .unload) == "Unload")
    #expect(editor.rows(for: .load).allSatisfy { $0.price == nil && $0.offer == nil })
    #expect(editor.rows(for: .load).map(\.good) == Good.allCases)
}

@MainActor
@Test("scenario: tapping a rival port")
func scenarioTappingARivalPort() throws {
    let (world, port) = try marketWorld(stock: [:])
    let snapshot = world.snapshot()
    let anchor = try #require(world.buildings[port]).anchor
    let target = RouteAuthoringTapTarget.resolve(tile: anchor, in: snapshot)
    #expect(target == .port(id: port))
    let viewModel = RouteAuthoringViewModel()
    viewModel.snapshot = snapshot
    viewModel.tapHandler(target: target)
    #expect(viewModel.inProgressWaypoints == [.port(id: port)])
}
