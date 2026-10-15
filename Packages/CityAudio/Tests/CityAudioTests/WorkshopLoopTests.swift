import CityCore
import Foundation
import Testing
@testable import CityAudio

// Spec `audio-playback`: "Every workshop has a work loop" and
// "Loop players follow their buildings".

private func shippedBindings() throws -> Bindings {
    let audio = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources/Audio")
    let manifest = try Manifest.load(from: Data(contentsOf: audio.appendingPathComponent("manifest.json")))
    return try Bindings.load(from: Data(contentsOf: audio.appendingPathComponent("bindings.json")), manifest: manifest)
}

@Test("scenario: every producing kind has a loop")
func everyProducingKindHasALoop() throws {
    let bindings = try shippedBindings()
    let producers = BuildingKind.allCases.filter { ProductionCatalog.recipe(for: $0) != nil && $0 != .monument }
    #expect(!producers.isEmpty)
    for kind in producers {
        for event in ["productionCycleCompleted", "productionResumed"] {
            let loops = (bindings.bindings[event] ?? []).filter { $0.loop == true && $0.kindFilter == kind && $0.bus == .loop }
            #expect(loops.count == 1, "\(event) has no loop for \(kind)")
        }
        let stops = (bindings.bindings["productionStalled"] ?? []).filter {
            $0.action == .stop && ($0.kindFilter == nil || $0.kindFilter == kind)
        }
        #expect(!stops.isEmpty, "productionStalled has no stop for \(kind)")
    }
}

@MainActor
@Test("scenario: a workshop's loop starts with its first cycle")
func workshopLoopStartsWithItsFirstCycle() {
    let cue = Bindings.Cue(file: "loop/oven.caf", bus: .loop, loop: true, kindFilter: .bakery)
    let bindings = Bindings(bindings: ["productionCycleCompleted": [cue]])
    var dispatched: [DispatchedCue] = []
    let coordinator = AudioCoordinator(bindings: bindings) { dispatched.append($0) }
    let bakery = EntityID(raw: 5)
    for _ in 0 ..< 3 {
        coordinator.consume(events: [.productionCycleCompleted(producer: bakery, kind: .bakery)])
    }
    #expect(dispatched.count == 1)
    #expect(dispatched.first?.entity == bakery)
}

@Test("scenario: two workshops of one kind each get a loop")
func twoWorkshopsEachGetALoop() {
    let first = EntityID(raw: 1)
    let second = EntityID(raw: 2)
    let chosen = LoopSelection.audible(
        [first: TileCoordinate(x: 1, y: 1), second: TileCoordinate(x: 9, y: 9)],
        listener: TileCoordinate(x: 0, y: 0)
    )
    #expect(chosen == [first, second])
}

@MainActor
@Test("scenario: a stop reaches the cue player")
func stopReachesTheCuePlayer() {
    let cue = Bindings.Cue(file: "loop/saw.caf", bus: .loop, loop: true)
    let bindings = Bindings(bindings: ["productionResumed": [cue]])
    var stopped: [EntityID] = []
    let coordinator = AudioCoordinator(bindings: bindings, dispatch: { _ in }, stop: { stopped.append($0) })
    let sawmill = EntityID(raw: 3)
    coordinator.consume(events: [.productionResumed(producer: sawmill, kind: .sawmill)])
    coordinator.stopLoop(for: sawmill)
    coordinator.stopLoop(for: sawmill)
    #expect(stopped == [sawmill], "only an active loop is stopped, once")
}

@Test("scenario: only the nearest loops play")
func onlyTheNearestLoopsPlay() {
    let wanted = Dictionary(uniqueKeysWithValues: (1 ... 10).map {
        (EntityID(raw: UInt32($0)), TileCoordinate(x: $0, y: 0))
    })
    let near = LoopSelection.audible(wanted, listener: TileCoordinate(x: 0, y: 0))
    #expect(near == Set((1 ... 8).map { EntityID(raw: UInt32($0)) }))
    let moved = LoopSelection.audible(wanted, listener: TileCoordinate(x: 11, y: 0))
    #expect(moved == Set((3 ... 10).map { EntityID(raw: UInt32($0)) }))
}

@Test func loopsWithoutPositionComeLast() {
    let placed = EntityID(raw: 1)
    let unplaced = EntityID(raw: 2)
    let chosen = LoopSelection.audible([placed: TileCoordinate(x: 50, y: 50), unplaced: nil], listener: nil, limit: 1)
    #expect(chosen == [placed])
}
