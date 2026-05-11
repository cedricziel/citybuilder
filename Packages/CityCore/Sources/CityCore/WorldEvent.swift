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
    case productionStalled(producer: EntityID)
    /// A producer transitioned from stalled to running this tick.
    case productionResumed(producer: EntityID)

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
        case let (.productionStalled(lEntity), .productionStalled(rEntity)):
            return lEntity == rEntity
        case let (.productionResumed(lEntity), .productionResumed(rEntity)):
            return lEntity == rEntity
        case let (.taxesCollected(lAmount), .taxesCollected(rAmount)):
            return lAmount == rAmount
        case let (.upkeepPaid(lAmount), .upkeepPaid(rAmount)):
            return lAmount == rAmount
        case let (.bankruptcyWarning(lTicks), .bankruptcyWarning(rTicks)):
            return lTicks == rTicks
        case (.bankruptcyResolved, .bankruptcyResolved):
            return true
        case (.gameOver, .gameOver):
            return true
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
        case let .carrierDeparted(carrier, _, _),
             let .carrierArrived(carrier, _, _, _):
            return carrier
        case let .productionCycleCompleted(producer, _),
             let .productionStalled(producer),
             let .productionResumed(producer):
            return producer
        case .forestHarvested,
             .placementRejected,
             .taxesCollected,
             .upkeepPaid,
             .bankruptcyWarning,
             .bankruptcyResolved,
             .gameOver:
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
        case .forestHarvested: return 3
        case .placementRejected: return 4
        case .carrierDeparted: return 5
        case .carrierArrived: return 6
        case .productionCycleCompleted: return 7
        case .productionStalled: return 8
        case .productionResumed: return 9
        case .taxesCollected: return 10
        case .upkeepPaid: return 11
        case .bankruptcyWarning: return 12
        case .bankruptcyResolved: return 13
        case .gameOver: return 14
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
