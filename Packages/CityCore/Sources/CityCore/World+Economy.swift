import Foundation

/// The economy system: taxes, upkeep and rival income per tick. Kept out
/// of `Systems.swift` so that file stays under SwiftLint's length limit.
extension World {
    mutating func runEconomySystem(signatureSources sources: [Building], events: inout [WorldEvent]) {
        guard !economy.gameOver else { return }
        if tickCount > 0, tickCount.isMultiple(of: Economy.taxIntervalTicks) {
            var taxes = taxesByOwner(sources: sources)
            let amount = taxes.removeValue(forKey: .player) ?? 0
            economy.credit(amount)
            creditRivals(taxes)
            // Only emit when actual money flowed — `taxesCollected` is a
            // meaningful event the audio layer binds to a coin sound, not
            // a 5-second heartbeat for empty cities.
            if amount > 0 {
                events.append(.taxesCollected(amount: amount))
            }
        }
        if tickCount > 0, tickCount.isMultiple(of: Economy.upkeepIntervalTicks) {
            var owed = upkeepByOwner(sources: sources)
            // Difficulty scaling applies to the player only.
            let totalUpkeep = difficulty.scaledUpkeep(owed.removeValue(forKey: .player) ?? 0)
            economy.deduct(totalUpkeep)
            creditRivals(owed.mapValues { -$0 })
            // Same as above — empty cities and free-upkeep buildings shouldn't
            // generate a per-interval no-op event.
            if totalUpkeep > 0 {
                events.append(.upkeepPaid(amount: totalUpkeep))
            }
        }
        // Track bankruptcy state transitions so events fire on the edges only.
        let priorDeficitTicks = economy.bankruptcyDeficitTicks
        let priorGameOver = economy.gameOver
        if economy.balance < 0 {
            economy.bankruptcyDeficitTicks &+= 1
            if priorDeficitTicks == 0 {
                events.append(.bankruptcyWarning(deficitTicks: economy.bankruptcyDeficitTicks))
            }
            // More ticks than the grace: a dip that starts on a collection
            // tick sees the next one (`hard-bankruptcy-grace` D1).
            if economy.bankruptcyDeficitTicks > difficulty.bankruptcyGraceTicks {
                economy.gameOver = true
                if !priorGameOver {
                    events.append(.gameOver)
                }
            }
        } else {
            economy.bankruptcyDeficitTicks = 0
            if priorDeficitTicks > 0 {
                events.append(.bankruptcyResolved)
            }
        }
    }

    /// Upkeep of every owner's operational buildings, unscaled.
    private func upkeepByOwner(sources: [Building]) -> [Owner: Int64] {
        var totals: [Owner: Int64] = [:]
        // A burning building still costs its upkeep.
        for building in buildings.values where building.state == .operational || building.state == .burning {
            totals[building.owner, default: 0] += upkeep(of: building, sources: sources)
        }
        return totals
    }

    /// Spec: `population-and-needs` / Taxes scale with tier; each house
    /// pays its owner (spec `economy` / Each owner has its own purse),
    /// with the owner's monument bonus.
    private func taxesByOwner(sources: [Building]) -> [Owner: Int64] {
        var taxes: [Owner: Int64] = [:]
        for (id, pop) in populations where buildings[id]?.state != .burning {
            taxes[owner(of: id), default: 0] += houseTax(house: id, population: pop, sources: sources)
        }
        for (owner, amount) in taxes {
            taxes[owner] = taxWithMonumentBonus(amount, for: owner)
        }
        return taxes
    }

    /// Books per-rival amounts in rival ID order. Rivals never go
    /// bankrupt; a negative treasury only makes them wait.
    private mutating func creditRivals(_ amounts: [Owner: Int64]) {
        for (owner, amount) in amounts.sorted(by: { ($0.key.rivalID ?? 0) < ($1.key.rivalID ?? 0) }) {
            credit(amount, to: owner)
        }
    }
}

public extension World {
    /// The player's tax and difficulty-scaled upkeep for one collection as
    /// the world stands: what the next collection would credit and deduct
    /// if nothing changed. Spec: `platform-shells` / Deficit hint.
    var playerTaxAndUpkeep: (tax: Int64, upkeep: Int64) {
        let sources = activeSignatureSources()
        return (
            taxesByOwner(sources: sources)[.player] ?? 0,
            difficulty.scaledUpkeep(upkeepByOwner(sources: sources)[.player] ?? 0)
        )
    }

    /// The difficulty-scaled upkeep of one collection a new `kind` would
    /// pay at `anchor`, with any culture upkeep relief there; the catalog
    /// upkeep without an anchor. Spec: `platform-shells` / Tool strip
    /// warns while the guide shows.
    func upkeepPerCollection(of kind: BuildingKind, at anchor: TileCoordinate?, owner: Owner = .player) -> Int64 {
        let base = BuildingCatalog.spec(for: kind).upkeep
        guard let anchor else { return difficulty.scaledUpkeep(base) }
        let candidate = Building(id: EntityID(raw: nextEntityRaw), kind: kind, anchor: anchor, state: .operational, owner: owner)
        return difficulty.scaledUpkeep(upkeep(of: candidate, sources: activeSignatureSources()))
    }

    /// Whether a road touches the building's footprint. Spec:
    /// `platform-shells` / First-hour guide.
    func isRoadConnected(_ building: Building) -> Bool {
        anyAdjacentRoad(anchor: building.anchor, footprint: building.footprint) != nil
    }
}
