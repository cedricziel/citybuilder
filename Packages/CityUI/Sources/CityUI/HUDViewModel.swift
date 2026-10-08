import CityCore
import Foundation

/// View-model owned by CityUI and updated each snapshot. Pure data — no
/// SwiftUI imports here so headless tests can drive it.
@Observable
public final class HUDViewModel {
    public var money: Int64
    public var population: UInt64
    /// Island summary the HUD currently displays. Driven by the camera
    /// center: enters when the camera centers on an island; sticky over
    /// water (keeps the previous island until the camera reaches a new
    /// one); nil only when the camera has never been on any island.
    public var currentIsland: IslandSummary?
    /// Season and year, such as "Spring 1200". Spec: `platform-shells` /
    /// HUD shows the date.
    public var dateText: String = ""
    /// SF Symbol for the time of day. Spec: `platform-shells` (city life).
    public var timeOfDaySymbol: String = "sun.max.fill"

    /// How long a placement rejection stays on screen.
    public static let rejectionDisplaySeconds: TimeInterval = 2.5

    private var rejection: (message: String, shownAt: Date)?

    public init(
        money: Int64 = 0,
        population: UInt64 = 0,
        currentIsland: IslandSummary? = nil
    ) {
        self.money = money
        self.population = population
        self.currentIsland = currentIsland
    }

    /// Apply a snapshot. Pure function from snapshot → HUD state.
    public func apply(_ snapshot: WorldSnapshot) {
        money = snapshot.economy.balance
        population = snapshot.totalPopulation
        dateText = snapshot.date.displayText
        timeOfDaySymbol = Self.symbol(for: TimeOfDay(tick: snapshot.tickCount).phase)
        currentIsland = resolveIsland(in: snapshot) ?? currentIsland.flatMap {
            // Sticky over water: keep showing the previous island, but
            // refresh its aggregates so any new deposits land in the
            // stocks row.
            snapshot.islandSummaries[$0.id]
        }
    }

    private func resolveIsland(in snapshot: WorldSnapshot) -> IslandSummary? {
        let cameraTile = snapshot.camera.centerTile()
        guard let id = snapshot.island(at: cameraTile) else { return nil }
        return snapshot.islandSummaries[id]
    }

    public var formattedMoney: String {
        formattedMoney(locale: .current)
    }

    /// Money with locale-grouped digits, e.g. "$1,000" in `en_US`.
    public func formattedMoney(locale: Locale) -> String {
        let prefix = money < 0 ? "-" : ""
        return "\(prefix)$\(abs(money).formatted(.number.grouping(.automatic).locale(locale)))"
    }

    /// Show `rejection` as the HUD's transient message, replacing any
    /// message already showing.
    public func showRejection(_ rejection: PlacementRejection, now: Date) {
        self.rejection = (PlacementRejectionText.message(for: rejection), now)
    }

    /// The rejection message to show at `date`, or nil once it expired.
    public func rejectionMessage(at date: Date) -> String? {
        guard let rejection, date.timeIntervalSince(rejection.shownAt) < Self.rejectionDisplaySeconds else {
            return nil
        }
        return rejection.message
    }

    public var formattedPopulation: String {
        "Pop. \(population)"
    }

    /// Name of the currently displayed island, or nil when the HUD's
    /// island row is hidden (camera never landed on any island).
    public var currentIslandName: String? {
        currentIsland?.name
    }

    /// Goods chips to render under the badge row. A chip exists for
    /// every good with non-zero stock OR non-zero capacity on the
    /// current island. Iteration follows `Good.allCases`, which is the
    /// stable catalog order — chips never reshuffle frame-to-frame.
    public var stocksRow: [HUDGoodChip] {
        guard let island = currentIsland else { return [] }
        return Good.allCases.compactMap { good in
            let stock = island.stockpile[good] ?? 0
            let capacity = island.capacity[good] ?? 0
            guard stock > 0 || capacity > 0 else { return nil }
            return HUDGoodChip(good: good, count: stock)
        }
    }
}

/// View-model entry for one chip in the HUD stocks row. The view
/// composes this with `GoodIconLoader.image(for:)` to render an
/// `Image + Text` chip.
public struct HUDGoodChip: Hashable, Sendable {
    public let good: Good
    public let count: Int

    public init(good: Good, count: Int) {
        self.good = good
        self.count = count
    }
}

extension HUDViewModel {
    static func symbol(for phase: TimeOfDay.Phase) -> String {
        switch phase {
        case .night: "moon.stars.fill"
        case .dawn: "sunrise.fill"
        case .day: "sun.max.fill"
        case .dusk: "sunset.fill"
        }
    }
}
