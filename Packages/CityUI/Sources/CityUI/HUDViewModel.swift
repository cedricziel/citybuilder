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
}
