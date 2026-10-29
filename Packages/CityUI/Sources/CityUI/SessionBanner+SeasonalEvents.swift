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
            return Self.banner(event, .warning, ["season": onset.displayName.lowercased()])
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
            return Self.banner(event, moment, ["count": "\(toll.count)"])
        case let .demolitionRejected(id, .notEnoughMoney):
            let kind = world.buildings[id].map { $0.ruinOf ?? $0.kind } ?? .ruins
            let what = world.buildings[id]?.kind == .ruins ? "these ruins" : "this burning building"
            return SessionBanner(
                title: "Not enough money",
                description: "Clearing \(what) costs \(HUDViewModel.formatMoney(World.clearingFee(of: kind), locale: .current))."
            )
        default:
            return nil
        }
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
