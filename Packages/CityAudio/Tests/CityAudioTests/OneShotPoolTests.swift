import CityCore
import Foundation
import Testing
@testable import CityAudio

// Spec `audio-playback`: "One-shots don't cut off long sounds" and
// "Every bound key is a real event".

@Test("scenario: a free node is used")
func freeNodeIsUsed() {
    let nodes = [OneShotPool.Slot(endsAt: 5, isLong: false), OneShotPool.Slot(endsAt: 0, isLong: false)]
    #expect(OneShotPool.pick(nodes, now: 1, from: 0) == 1)
}

@Test("scenario: a long peal is not cut off")
func longPealIsNotCutOff() {
    let nodes = [
        OneShotPool.Slot(endsAt: 4, isLong: true),
        OneShotPool.Slot(endsAt: 4.5, isLong: false),
        OneShotPool.Slot(endsAt: 4.2, isLong: false),
        OneShotPool.Slot(endsAt: 4.8, isLong: false)
    ]
    #expect(OneShotPool.pick(nodes, now: 1, from: 0) == 2)
    let allLong = nodes.map { OneShotPool.Slot(endsAt: $0.endsAt, isLong: true) }
    #expect(OneShotPool.pick(allLong, now: 1, from: 0) == 0)
}

@Test("scenario: bound keys are event names")
func boundKeysAreEventNames() throws {
    let entity = EntityID(raw: 1)
    let tile = TileCoordinate(x: 0, y: 0)
    let events: [WorldEvent] = [
        .buildingPlaced(building: entity, kind: .house, anchor: tile),
        .buildingDemolished(building: entity, kind: .house, anchor: tile),
        .constructionCompleted(building: entity, kind: .house, anchor: tile),
        .materialsDeducted(building: entity, cost: [:]),
        .constructionWaitingForMaterials(building: entity, missing: [:]),
        .constructionStarted(building: entity),
        .forestHarvested(at: tile), .forestPlanted(at: tile, forester: entity),
        .placementRejected(kind: .house, anchor: tile),
        .carrierDeparted(carrier: entity, from: tile, good: .wood),
        .carrierArrived(carrier: entity, at: tile, good: .wood, amount: 1),
        .productionCycleCompleted(producer: entity, kind: .sawmill),
        .productionStalled(producer: entity, kind: .sawmill),
        .productionResumed(producer: entity, kind: .sawmill),
        .taxesCollected(amount: 1), .upkeepPaid(amount: 1), .bankruptcyWarning(deficitTicks: 1),
        .bankruptcyResolved, .gameOver, .seasonChanged(.winter), .historyEvent(.tradeCaravan),
        .ageAdvanced(.medieval), .scenarioWon, .fuelRanOut(building: entity, kind: .smelter),
        .monumentCompleted(building: entity), .commissionStarted(building: entity),
        .commissionEnded(building: entity), .caravanSold(building: entity, goods: [:], revenue: 1),
        .rivalAgeAdvanced(1, .medieval),
        .tradeCompleted(rival: 1, good: .wood, quantity: 1, total: 1, direction: .bought),
        .marketTraded(good: .wood, quantity: 1, total: 1, direction: .sold),
        .orderOffered(order: 1, issuer: .crown), .orderAccepted(order: 1), .orderFulfilled(order: 1, reward: 1),
        .orderFailed(order: 1), .orderExpired(order: 1)
    ]
    let keys = Set(events.map(AudioCoordinator.caseKey(for:)))
    let audio = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources/Audio")
    let manifest = try Manifest.load(from: Data(contentsOf: audio.appendingPathComponent("manifest.json")))
    let bindings = try Bindings.load(from: Data(contentsOf: audio.appendingPathComponent("bindings.json")), manifest: manifest)
    for key in bindings.bindings.keys where !key.hasPrefix("ui.") {
        #expect(keys.contains(key), "\(key) is no event the coordinator reports")
    }
}
