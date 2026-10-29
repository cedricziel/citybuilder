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
            return Self.warningBanner(SeasonalEventOnset(event: event, season: onset))
        case let .seasonalEventStarted(event):
            let end = world.seasonalEvents.active.map { Self.endDate(of: $0.lastTick, in: world) } ?? ""
            return Self.banner(event, .onset, ["date": end])
        case let .buildingCaughtFire(_, kind):
            return Self.banner(.fire, .ignition, ["building": BuildTool.place(kind).displayName.lowercased()])
        case let .seasonalEventEnded(event, toll):
            let moment: SeasonalBannerKind = switch (event.effect, toll.fires, toll.count) {
            case (.fire, 0, _): .endNoFire
            case (.fire, _, 0): .endNoLoss
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

    /// "1 building", "3 buildings".
    static func counted(_ count: Int, _ noun: String) -> String {
        "\(count) \(noun)\(count == 1 ? "" : "s")"
    }

    /// What the event chip shows again: while a fire burns, that it burns,
    /// else the warning.
    func seasonalChipBanner() -> SessionBanner? {
        if let fire = world.seasonalEvents.fire?.fires.first, let kind = world.buildings[fire.building]?.kind {
            return Self.banner(.fire, .ignition, ["building": BuildTool.place(kind).displayName.lowercased()])
        }
        return world.currentSeasonalEvent.flatMap(Self.warningBanner)
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
