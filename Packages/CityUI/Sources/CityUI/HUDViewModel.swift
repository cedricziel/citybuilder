import CityCore
import Foundation

/// View-model owned by CityUI and updated each snapshot. Pure data — no
/// SwiftUI imports here so headless tests can drive it.
@Observable
public final class HUDViewModel {
    public var money: Int64
    public var population: UInt64

    public init(money: Int64 = 0, population: UInt64 = 0) {
        self.money = money
        self.population = population
    }

    /// Apply a snapshot. Pure function from snapshot → HUD state.
    /// Money/population aggregation arrives in M4; for M2 the HUD just
    /// reflects the tick count so the wiring is observably alive.
    public func apply(_ snapshot: WorldSnapshot) {
        money = Int64(snapshot.tickCount)
        population = UInt64(snapshot.occupiedTiles.count)
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
