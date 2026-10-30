import CityCore
import Foundation

/// Seasonal event banners, with their text from the events pack. Spec:
/// `seasonal-events` / Banner text; `platform-shells` / Seasonal events show
/// banners and a chip.
extension GameSession {
    /// The banner for a seasonal event, or nil for any other event.
    func seasonalEventBanner(for event: WorldEvent) -> SessionBanner? {
        switch event {
        case let .seasonalEventWarned(event, onset):
            return warningBanner(SeasonalEventOnset(event: event, season: onset))
        case .seasonalEventStarted(.festival):
            let end = world.seasonalEvents.festivalUntil.map { Self.endDate(of: $0, in: world) } ?? ""
            return Self.banner(.festival, .held, ["bonus": "\(world.difficulty.festivalTaxBonusPercent)", "date": end])
        case let .seasonalEventStarted(event):
            let end = world.seasonalEvents.active.map { Self.endDate(of: $0.lastTick, in: world) } ?? ""
            return Self.banner(event, .onset, ["date": end])
        case let .buildingCaughtFire(id, kind):
            let moment: SeasonalBannerKind = isAnswered(id) ? .ignitionCovered : .ignition
            return Self.banner(.fire, moment, ["building": BuildTool.place(kind).displayName.lowercased()])
        case let .seasonalEventEnded(event, toll):
            let moment: SeasonalBannerKind = switch (event.effect, toll.fires, toll.count) {
            case (.fire, 0, _): .endNoFire
            case (.fire, _, 0): .endNoLoss
            case (.festival, _, _): .missed
            default: .end
            }
            let values = [
                "count": "\(toll.count)", "buildings": Self.counted(toll.count, "building"),
                "residents": Self.counted(toll.count, "resident")
            ]
            return Self.banner(event, moment, values)
        case let .demolitionRejected(id, .notEnoughMoney):
            guard let building = world.buildings[id] else { return nil }
            let what = building.kind == .ruins ? "these ruins" : "this burning building"
            return SessionBanner(
                title: "Not enough money",
                description: "Clearing \(what) costs \(HUDViewModel.formatMoney(World.clearingFee(for: building), locale: .current))."
            )
        default:
            return nil
        }
    }

    /// A player fire watch would answer a fire in `id`.
    private func isAnswered(_ id: EntityID) -> Bool {
        guard let target = world.buildings[id] else { return false }
        return world.buildings.values.contains { watch in
            watch.kind == .fireWatch && watch.owner == target.owner && watch.state == .operational
                && world.fireWatchCovers(watch, target)
        }
    }

    /// "1 building", "3 buildings".
    nonisolated static func counted(_ count: Int, _ noun: String) -> String {
        "\(count) \(noun)\(count == 1 ? "" : "s")"
    }

    /// What the event chip shows again: while a fire burns, that it burns,
    /// else the warning.
    func seasonalChipBanner() -> SessionBanner? {
        // The same banner as the ignition's, covered or not, so it matches the one on screen.
        if let fire = world.seasonalEvents.fire?.fires.first, let kind = world.buildings[fire.building]?.kind {
            return seasonalEventBanner(for: .buildingCaughtFire(building: fire.building, kind: kind))
        }
        return world.currentSeasonalEvent.flatMap(warningBanner)
    }

    /// A hazard's warning, or a festival's request with its orders.
    private func warningBanner(_ onset: SeasonalEventOnset) -> SessionBanner? {
        guard onset.event.effect == .festival else { return Self.warningBanner(onset) }
        let pair = (world.seasonalEvents.festival?.orders ?? []).compactMap(world.order)
        guard let bread = pair.first, let luxury = pair.last, pair.count == 2 else { return nil }
        return Self.banner(onset.event, .request, [
            "bread": "\(bread.quantity)", "luxury": "\(luxury.quantity)",
            "luxuryGood": InspectorViewModel.goodName(luxury.good), "deadline": Self.endDate(of: bread.deadlineTick, in: world)
        ])
    }

    /// The warning of `onset`, as first shown and as the chip shows it again.
    static func warningBanner(_ onset: SeasonalEventOnset) -> SessionBanner? {
        banner(onset.event, .warning, ["season": onset.season.displayName.lowercased()])
    }

    /// The pack's banner for `moment`, its placeholders filled.
    static func banner(_ event: SeasonalEvent, _ moment: SeasonalBannerKind, _ values: [String: String]) -> SessionBanner? {
        guard let banner = event.banners[moment] else { return nil }
        return SessionBanner(title: fill(banner.title, values), description: fill(banner.text, values))
    }

    static func fill(_ text: String, _ values: [String: String]) -> String {
        values.reduce(text) { $0.replacingOccurrences(of: "{\($1.key)}", with: $1.value) }
    }

    /// "End of Summer 1203": the season of `tick`, as the HUD shows a date.
    static func endDate(of tick: UInt64, in world: World) -> String {
        "End of \(world.calendar.date(atTick: tick).displayText)"
    }
}
