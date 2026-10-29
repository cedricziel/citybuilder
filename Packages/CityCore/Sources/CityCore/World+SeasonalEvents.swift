import Foundation

/// One seasonal event a year, decided at its start and warned a season
/// ahead. Spec: `seasonal-events`.
extension World {
    /// The purposes a seasonal event draws for, each with its own salt so
    /// the draws never share a sequence with each other or with the history
    /// events (`add-event-counterplay` D1).
    enum SeasonalEventDraw: UInt64 {
        case decision = 0x5EA5_0000_0000_0001
        case ignition = 0x5EA5_0000_0000_0002
        case area = 0x5EA5_0000_0000_0003
        case district = 0x5EA5_0000_0000_0004
    }

    /// A generator derived from the seed, the year, the purpose and an
    /// index; the world's own generator is never touched.
    func seasonalEventRNG(_ draw: SeasonalEventDraw, year: Int, index: UInt64 = 0) -> DeterministicRNG {
        DeterministicRNG(
            seed: (seed ^ draw.rawValue) &+ UInt64(bitPattern: Int64(year)) &* 0xC2B2_AE3D_27D4_EB4F &+ index &* 0x1656_67B1_9E37_79F9
        )
    }

    /// The event for `year` and its onset season, or nil: a chapter's
    /// scheduled event, else a draw by the difficulty's chance and the
    /// events' weights among those the player's age allows.
    public func seasonalEvent(forYear year: Int) -> SeasonalEventOnset? {
        if let scheduled = seasonalEvents.schedule.first(where: { $0.year == year }) {
            return SeasonalEventOnset(event: scheduled.event, season: scheduled.onset)
        }
        guard seasonalEvents.enabled, seasonalEvents.randomEvents,
              year - calendar.startYear + 1 >= difficulty.firstSeasonalEventYear
        else { return nil }
        var rng = seasonalEventRNG(.decision, year: year)
        guard rng.next() % 100 < difficulty.seasonalEventChancePercent else { return nil }
        let pool = SeasonalEvent.allCases.filter { $0.minAge <= age }.flatMap { event in
            Array(repeating: event, count: event.weights[difficulty] ?? 0)
        }
        guard !pool.isEmpty else { return nil }
        let event = pool[Int(rng.next() % UInt64(pool.count))]
        return SeasonalEventOnset(event: event, season: event.seasons[Int(rng.next() % UInt64(event.seasons.count))])
    }

    mutating func runSeasonalEventSystem(events: inout [WorldEvent]) {
        guard calendar.isActive, seasonalEvents.enabled || !seasonalEvents.schedule.isEmpty else { return }
        if seasonalEvents.fire != nil {
            runFireSystem(events: &events)
        }
        if let active = seasonalEvents.active, tickCount >= active.lastTick {
            endSeasonalEvent(events: &events)
        }
        // A new game's first tick stands in for the spring tick 0 that never
        // runs, so a chapter can schedule an event in its first year.
        guard tickCount == 1 || tickCount.isMultiple(of: CalendarState.ticksPerSeason) else { return }
        let today = date
        if today.season == .spring {
            decideSeasonalEvent(forYear: today.year)
        }
        if let warned = seasonalEvents.warned, warned.season == today.season {
            startSeasonalEvent(warned, events: &events)
        } else if let plan = seasonalEvents.plan, plan.year == today.year, let onset = plan.onset, !seasonalEvents.isBusy {
            announceSeasonalEvent(onset, today: today.season, events: &events)
        }
    }

    /// Stores the year's decision. An event still open from an earlier
    /// year (only a hand-edited save) makes this year's skip.
    private mutating func decideSeasonalEvent(forYear year: Int) {
        let onset = seasonalEvents.isBusy ? nil : seasonalEvent(forYear: year)
        seasonalEvents.plan = SeasonalEventPlan(year: year, onset: onset)
    }

    /// A hazard is warned the season before its onset, a festival is
    /// requested in its own season; either only with targets, else the
    /// year has no event.
    private mutating func announceSeasonalEvent(
        _ onset: SeasonalEventOnset, today: Season, events: inout [WorldEvent]
    ) {
        let announces = onset.event.effect.isHazard
            ? onset.season.rawValue == today.rawValue + 1
            : onset.season == today
        guard announces else { return }
        let scheduled = seasonalEvents.schedule.contains { $0.year == date.year }
        guard hasSeasonalEventTargets(onset.event.effect, scheduled: scheduled) else {
            seasonalEvents.plan = SeasonalEventPlan(year: date.year, onset: nil)
            return
        }
        seasonalEvents.warned = onset
        events.append(.seasonalEventWarned(event: onset.event, onset: onset.season))
    }

    private mutating func startSeasonalEvent(_ onset: SeasonalEventOnset, events: inout [WorldEvent]) {
        // A fire may burn into the next season; the rains end it then.
        let seasons: UInt64 = onset.event.effect == .fire ? 2 : 1
        seasonalEvents.warned = nil
        seasonalEvents.active = ActiveSeasonalEvent(
            event: onset.event, startTick: tickCount, lastTick: tickCount + seasons * CalendarState.ticksPerSeason - 1
        )
        if onset.event.effect == .fire {
            seasonalEvents.fire = FireEventState(ignitionTicks: fireIgnitionTicks())
        }
        events.append(.seasonalEventStarted(event: onset.event))
    }

    /// Ends the event under way. Fires still burning go out without
    /// becoming ruins: the rains.
    mutating func endSeasonalEvent(events: inout [WorldEvent]) {
        guard let active = seasonalEvents.active else { return }
        for fire in seasonalEvents.fire?.fires ?? [] {
            extinguish(fire.building, events: &events)
        }
        let fire = seasonalEvents.fire
        seasonalEvents.active = nil
        seasonalEvents.fire = nil
        let toll = SeasonalEventToll(count: fire?.lost ?? 0, fires: fire?.caught.count ?? 0)
        events.append(.seasonalEventEnded(event: active.event, toll: toll))
    }

    /// Whether the town has what the event strikes. A chapter's event needs
    /// one target; a drawn one needs a town worth striking. The festival
    /// waits for the marketplace (#238 M2), so it has none yet.
    func hasSeasonalEventTargets(_ effect: SeasonalEffect, scheduled: Bool) -> Bool {
        let minimum = scheduled ? 1 : Self.seasonalEventMinimumTargets
        let owned = buildings.values.filter { $0.owner == .player && $0.state == .operational }
        switch effect {
        case .fire:
            let flammable = owned.filter { Self.isFlammable($0.kind) }
            return flammable.count >= minimum && flammable.contains { Self.canIgnite($0.kind) }
        case .blight:
            return owned.contains { $0.kind.isCrop }
        case .fever:
            return owned.count { $0.kind == .house && (populations[$0.id]?.population ?? 0) > 0 } >= minimum
        case .festival:
            return false
        }
    }

    static let seasonalEventMinimumTargets = 6

    /// Houses and producers; not monuments, shipyards or signature buildings.
    static func canIgnite(_ kind: BuildingKind) -> Bool {
        kind == .house || (ProductionCatalog.recipe(for: kind) != nil && kind != .shipyard
            && !BuildingKind.signatures.contains(kind) && !kind.isCultureSignature)
    }

    /// What a fire can burn: what can ignite, and the town's wooden stores
    /// and halls.
    static func isFlammable(_ kind: BuildingKind) -> Bool {
        canIgnite(kind) || [.warehouse, .granary, .library, .fireWatch].contains(kind)
    }
}
