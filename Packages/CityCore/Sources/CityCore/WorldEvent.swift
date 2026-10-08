import Foundation

/// Transient simulation-meaningful occurrences emitted by `World.tick()` and
/// surfaced through `TickResult.events`. Per spec `world-events`.
///
/// `WorldEvent` is deliberately NOT `Codable`: events are never persisted,
/// never serialized into the save format, and must not become a dependency
/// surface for any external consumer. Consumers (the audio layer, the CLI's
/// event-log dump) pattern-match against the cases directly.
public enum WorldEvent: Sendable {
    // MARK: Buildings & terrain (entity-scoped or tile-scoped)

    /// A new building was successfully placed at `anchor` on this tick.
    case buildingPlaced(building: EntityID, kind: BuildingKind, anchor: TileCoordinate)
    /// An existing building was demolished on this tick.
    case buildingDemolished(building: EntityID, kind: BuildingKind, anchor: TileCoordinate)
    /// A building's state flipped from `.constructing` to `.operational` on this tick.
    case constructionCompleted(building: EntityID, kind: BuildingKind, anchor: TileCoordinate)
    /// Materials were deducted from the island's goods buffers at
    /// placement time, satisfying the building's `materialCost`. The
    /// audio layer (eventually) plays a short tally cue on this event.
    /// Spec: `world-events` / Requirement: materialsDeducted event.
    case materialsDeducted(building: EntityID, cost: [Good: Int])
    /// A construction site was placed but the island's goods buffers
    /// could not fully cover its `materialCost`. The building enters
    /// `.constructing` + `.waitingForMaterials`. `missing` carries the
    /// per-good shortfall remaining after the partial deduction. Spec:
    /// `world-events` / `add-construction-stalls`.
    case constructionWaitingForMaterials(building: EntityID, missing: [Good: Int])
    /// A waiting construction site has had its last required good
    /// delivered: `materialsDelivered` now satisfies `materialCost`
    /// for every good. The building flips `constructionState` to
    /// `.actively` on this tick.
    case constructionStarted(building: EntityID)
    /// A forest tile was cleared (harvested by the player or consumed by a lumberjack).
    case forestHarvested(at: TileCoordinate)
    /// A placement command was rejected. Emitted only if the command is dispatched
    /// without prior `canPlace` validation; the UI normally pre-filters these.
    case placementRejected(kind: BuildingKind, anchor: TileCoordinate)

    // MARK: Carriers

    /// A carrier was spawned by its producer this tick and started walking its path.
    case carrierDeparted(carrier: EntityID, from: TileCoordinate, good: Good)
    /// A carrier reached its destination tile this tick and deposited its cargo.
    case carrierArrived(carrier: EntityID, at: TileCoordinate, good: Good, amount: Int)

    // MARK: Production

    /// A producer completed one full production cycle this tick.
    case productionCycleCompleted(producer: EntityID, kind: BuildingKind)
    /// A producer transitioned from running to stalled this tick.
    case productionStalled(producer: EntityID, kind: BuildingKind)
    /// A producer transitioned from stalled to running this tick.
    case productionResumed(producer: EntityID, kind: BuildingKind)

    // MARK: Economy

    /// Taxes were collected this tick (tax-interval boundary).
    case taxesCollected(amount: Int64)
    /// Upkeep was deducted this tick (upkeep-interval boundary).
    case upkeepPaid(amount: Int64)
    /// The treasury went negative this tick after being non-negative on the prior tick.
    case bankruptcyWarning(deficitTicks: UInt64)
    /// The treasury returned to non-negative within the grace window.
    case bankruptcyResolved
    /// The bankruptcy grace expired this tick; the game is over.
    case gameOver

    // MARK: Calendar

    /// A new season began this tick. Spec: `calendar-and-events`.
    case seasonChanged(Season)
    /// A history event fired and applied this tick.
    case historyEvent(HistoryEvent)
    /// The city entered a new age. Spec: `historical-ages`.
    case ageAdvanced(Age)
    /// Every scenario goal is met. Spec: `difficulty-and-goals`.
    case scenarioWon

    // MARK: Age signatures

    /// A fuelled building's burn found too little fuel after a burn that
    /// succeeded. Spec: `age-signatures`.
    case fuelRanOut(building: EntityID, kind: BuildingKind)
    /// The monument completed its last project stage.
    case monumentCompleted(building: EntityID)
    /// A gallery commission was paid for and started.
    case commissionStarted(building: EntityID)
    /// A gallery commission ran out.
    case commissionEnded(building: EntityID)

    // MARK: Culture signatures

    /// A caravanserai's caravan sold `goods` for `revenue`. Spec:
    /// `culture-signatures` / Caravans sell at base price.
    case caravanSold(building: EntityID, goods: [Good: Int], revenue: Int64)

    // MARK: Rival towns

    /// A rival town entered a new age. Spec: `rival-towns` / Rival ages.
    case rivalAgeAdvanced(RivalID, Age)
}

extension WorldEvent: Equatable {
    // swiftlint:disable:next cyclomatic_complexity
    public static func == (lhs: WorldEvent, rhs: WorldEvent) -> Bool {
        switch (lhs, rhs) {
        case let (.buildingPlaced(lEntity, lKind, lAnchor), .buildingPlaced(rEntity, rKind, rAnchor)):
            return lEntity == rEntity && lKind == rKind && lAnchor == rAnchor
        case let (.buildingDemolished(lEntity, lKind, lAnchor), .buildingDemolished(rEntity, rKind, rAnchor)):
            return lEntity == rEntity && lKind == rKind && lAnchor == rAnchor
        case let (.constructionCompleted(lEntity, lKind, lAnchor), .constructionCompleted(rEntity, rKind, rAnchor)):
            return lEntity == rEntity && lKind == rKind && lAnchor == rAnchor
        case let (.materialsDeducted(lBuilding, lCost), .materialsDeducted(rBuilding, rCost)):
            return lBuilding == rBuilding && lCost == rCost
        case let (
            .constructionWaitingForMaterials(lBuilding, lMissing),
            .constructionWaitingForMaterials(rBuilding, rMissing)
        ):
            return lBuilding == rBuilding && lMissing == rMissing
        case let (.constructionStarted(lBuilding), .constructionStarted(rBuilding)):
            return lBuilding == rBuilding
        case let (.forestHarvested(lAt), .forestHarvested(rAt)):
            return lAt == rAt
        case let (.placementRejected(lKind, lAnchor), .placementRejected(rKind, rAnchor)):
            return lKind == rKind && lAnchor == rAnchor
        case let (.carrierDeparted(lEntity, lFrom, lGood), .carrierDeparted(rEntity, rFrom, rGood)):
            return lEntity == rEntity && lFrom == rFrom && lGood == rGood
        case let (.carrierArrived(lEntity, lAt, lGood, lAmount), .carrierArrived(rEntity, rAt, rGood, rAmount)):
            return lEntity == rEntity && lAt == rAt && lGood == rGood && lAmount == rAmount
        case let (.productionCycleCompleted(lEntity, lKind), .productionCycleCompleted(rEntity, rKind)):
            return lEntity == rEntity && lKind == rKind
        case let (.productionStalled(lEntity, lKind), .productionStalled(rEntity, rKind)):
            return lEntity == rEntity && lKind == rKind
        case let (.productionResumed(lEntity, lKind), .productionResumed(rEntity, rKind)):
            return lEntity == rEntity && lKind == rKind
        case let (.taxesCollected(lAmount), .taxesCollected(rAmount)):
            return lAmount == rAmount
        case let (.upkeepPaid(lAmount), .upkeepPaid(rAmount)):
            return lAmount == rAmount
        case let (.bankruptcyWarning(lTicks), .bankruptcyWarning(rTicks)):
            return lTicks == rTicks
        case (.bankruptcyResolved, .bankruptcyResolved), (.gameOver, .gameOver), (.scenarioWon, .scenarioWon):
            return true
        case let (.seasonChanged(lSeason), .seasonChanged(rSeason)):
            return lSeason == rSeason
        case let (.historyEvent(lEvent), .historyEvent(rEvent)):
            return lEvent == rEvent
        case let (.ageAdvanced(lAge), .ageAdvanced(rAge)):
            return lAge == rAge
        case let (.fuelRanOut(lBuilding, lKind), .fuelRanOut(rBuilding, rKind)):
            return lBuilding == rBuilding && lKind == rKind
        case let (.monumentCompleted(lBuilding), .monumentCompleted(rBuilding)),
             let (.commissionStarted(lBuilding), .commissionStarted(rBuilding)),
             let (.commissionEnded(lBuilding), .commissionEnded(rBuilding)):
            return lBuilding == rBuilding
        case let (.caravanSold(lBuilding, lGoods, lRevenue), .caravanSold(rBuilding, rGoods, rRevenue)):
            return lBuilding == rBuilding && lGoods == rGoods && lRevenue == rRevenue
        case let (.rivalAgeAdvanced(lRival, lAge), .rivalAgeAdvanced(rRival, rAge)):
            return lRival == rRival && lAge == rAge
        default:
            return false
        }
    }
}

public extension WorldEvent {
    /// The primary `EntityID` this event involves, used as the primary key for
    /// stable event ordering inside a single tick (M3). Tile-only and
    /// economy-wide events return `nil`; they sort after entity-bearing events
    /// using `caseOrdinal` as the secondary key.
    var primaryEntityID: EntityID? {
        switch self {
        case let .buildingPlaced(building, _, _),
             let .buildingDemolished(building, _, _),
             let .constructionCompleted(building, _, _):
            return building
        case let .materialsDeducted(building, _):
            return building
        case let .constructionWaitingForMaterials(building, _),
             let .constructionStarted(building):
            return building
        case let .carrierDeparted(carrier, _, _),
             let .carrierArrived(carrier, _, _, _):
            return carrier
        case let .productionCycleCompleted(producer, _),
             let .productionStalled(producer, _),
             let .productionResumed(producer, _):
            return producer
        case let .fuelRanOut(building, _):
            return building
        case let .monumentCompleted(building),
             let .commissionStarted(building),
             let .commissionEnded(building),
             let .caravanSold(building, _, _):
            return building
        case .forestHarvested,
             .placementRejected,
             .taxesCollected,
             .upkeepPaid,
             .bankruptcyWarning,
             .bankruptcyResolved,
             .gameOver,
             .seasonChanged,
             .historyEvent,
             .ageAdvanced,
             .scenarioWon,
             .rivalAgeAdvanced:
            return nil
        }
    }

    /// The `BuildingKind` payload exposed by an event's case, if any. Used
    /// by audio bindings to filter cues per building kind (e.g. only
    /// dispatch the sawmill loop when the event is for a sawmill). Events
    /// without a kind payload return nil.
    var buildingKind: BuildingKind? {
        switch self {
        case let .buildingPlaced(_, kind, _),
             let .buildingDemolished(_, kind, _),
             let .constructionCompleted(_, kind, _),
             let .productionCycleCompleted(_, kind),
             let .productionStalled(_, kind),
             let .productionResumed(_, kind),
             let .fuelRanOut(_, kind):
            return kind
        case let .placementRejected(kind, _):
            return kind
        case .materialsDeducted,
             .constructionWaitingForMaterials,
             .constructionStarted,
             .forestHarvested,
             .carrierDeparted,
             .carrierArrived,
             .taxesCollected,
             .upkeepPaid,
             .bankruptcyWarning,
             .bankruptcyResolved,
             .gameOver,
             .seasonChanged,
             .historyEvent,
             .ageAdvanced,
             .scenarioWon,
             .monumentCompleted,
             .commissionStarted,
             .commissionEnded,
             .caravanSold,
             .rivalAgeAdvanced:
            return nil
        }
    }

    /// Stable case ordinal used as the secondary sort key for events that share
    /// (or lack) a primary entity. Hand-maintained next to the enum so that
    /// reordering cases above does not silently change the wire order of the
    /// event log.
    var caseOrdinal: Int {
        switch self {
        case .buildingPlaced: return 0
        case .buildingDemolished: return 1
        case .constructionCompleted: return 2
        case .materialsDeducted: return 3
        case .constructionWaitingForMaterials: return 4
        case .constructionStarted: return 5
        case .forestHarvested: return 6
        case .placementRejected: return 7
        case .carrierDeparted: return 8
        case .carrierArrived: return 9
        case .productionCycleCompleted: return 10
        case .productionStalled: return 11
        case .productionResumed: return 12
        case .taxesCollected: return 13
        case .upkeepPaid: return 14
        case .bankruptcyWarning: return 15
        case .bankruptcyResolved: return 16
        case .gameOver: return 17
        case .seasonChanged: return 18
        case .historyEvent: return 19
        case .ageAdvanced: return 20
        case .scenarioWon: return 21
        case .fuelRanOut: return 22
        case .monumentCompleted: return 23
        case .commissionStarted: return 24
        case .commissionEnded: return 25
        case .caravanSold: return 26
        case .rivalAgeAdvanced: return 27
        }
    }
}

extension [WorldEvent] {
    /// Stable sort by `(primaryEntityID, caseOrdinal, insertion-index)` so the
    /// concatenated event log across ticks is byte-identical between two
    /// runs that share state and inputs. Entity-bearing events sort by
    /// ascending `EntityID.raw`; events with `primaryEntityID == nil`
    /// (economy, tile-only) sort after all entity-bearing events, by their
    /// declared `caseOrdinal`. Insertion order is preserved as the tertiary
    /// key (Swift's `sort` is not stable — we decorate-sort-undecorate).
    func stablySortedForEmission() -> [WorldEvent] {
        // Decorate with original index.
        let decorated = enumerated().map { (idx: $0.offset, event: $0.element) }
        let sorted = decorated.sorted { lhs, rhs in
            let lhsId = lhs.event.primaryEntityID?.raw ?? .max
            let rhsId = rhs.event.primaryEntityID?.raw ?? .max
            if lhsId != rhsId { return lhsId < rhsId }
            if lhs.event.caseOrdinal != rhs.event.caseOrdinal {
                return lhs.event.caseOrdinal < rhs.event.caseOrdinal
            }
            return lhs.idx < rhs.idx
        }
        return sorted.map(\.event)
    }
}
