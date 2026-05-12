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
        let prefix = money < 0 ? "-" : ""
        let magnitude = abs(money)
        return "\(prefix)$\(magnitude)"
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
