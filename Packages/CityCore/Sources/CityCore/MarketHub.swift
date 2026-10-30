import Foundation

/// How a market hub serves houses, from its building's pack item.
/// Spec: `population-and-needs` / Market porters supply houses
/// (visible-distribution design D9).
public struct HubSpec: Equatable, Sendable {
    /// Road tiles from the hub to the houses it serves, at most.
    public let radius: Int
    /// Houses served per porter beyond the first.
    public let housesPerPorter: Int
    public let maxPorters: Int
    /// Units a porter carries at most.
    public let basketUnits: Int
    /// Consumptions of its houses the hub keeps of each good before it
    /// pulls more from other stores.
    public let reserveConsumptions: Int

    public init(radius: Int, housesPerPorter: Int, maxPorters: Int, basketUnits: Int, reserveConsumptions: Int) {
        self.radius = radius
        self.housesPerPorter = housesPerPorter
        self.maxPorters = maxPorters
        self.basketUnits = basketUnits
        self.reserveConsumptions = reserveConsumptions
    }

    /// Porters a hub serving `houses` houses keeps.
    public func porters(serving houses: Int) -> Int {
        min(maxPorters, 1 + houses / housesPerPorter)
    }
}

/// The market serving a house: its hub and the road distance to it.
public struct MarketServing: Hashable, Sendable {
    public let hub: EntityID
    public let distance: Int

    public init(hub: EntityID, distance: Int) {
        self.hub = hub
        self.distance = distance
    }
}
