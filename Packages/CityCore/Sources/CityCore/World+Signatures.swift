import Foundation

/// Signature effects on houses, the monument project and gallery
/// commissions. Spec: `age-signatures`.
public struct HouseModifiers: Hashable, Sendable {
    /// Within 4 tiles of a fuelled steam engine: 2 less capacity.
    public var smoky: Bool
    /// Within 10 tiles of a fuelled power plant: 2 more capacity.
    public var energised: Bool
    /// Within 8 tiles of a gallery with a running commission: grows and
    /// advances a tier twice as fast.
    public var inspired: Bool

    public init(smoky: Bool = false, energised: Bool = false, inspired: Bool = false) {
        self.smoky = smoky
        self.energised = energised
        self.inspired = inspired
    }

    public static let none = HouseModifiers()

    /// Growth and tier timers divide by this: 2 when inspired.
    public var paceDivisor: UInt64 {
        inspired ? 2 : 1
    }

    /// `tier`'s capacity, −2 when smoky and +2 when energised, at least 1
    /// (design D8).
    public func capacity(of tier: HouseTier) -> UInt32 {
        let modified = Int(tier.capacity) - (smoky ? 2 : 0) + (energised ? 2 : 0)
        return UInt32(max(1, modified))
    }
}

public extension World {
    static let monumentStages: UInt8 = 25
    static let commissionCost: Int64 = 200
    static let commissionTicks: UInt32 = 1200

    /// Signature modifiers on the house `id`; none for other buildings.
    func houseModifiers(of id: EntityID) -> HouseModifiers {
        guard let house = buildings[id], house.kind == .house else { return .none }
        return houseModifiers(of: house, sources: activeSignatureSources())
    }

    /// The house's capacity with its signature modifiers (design D8).
    func houseCapacity(of id: EntityID) -> UInt32 {
        let tier = populations[id]?.tier ?? .peasants
        return houseModifiers(of: id).capacity(of: tier)
    }

    /// True once the monument has completed every project stage.
    var hasCompletedMonument: Bool {
        buildings.values.contains { $0.isCompletedMonument }
    }
}

public extension Building {
    var isCompletedMonument: Bool {
        kind == .monument && projectStages >= World.monumentStages
    }
}

extension World {
    func houseModifiers(of house: Building, sources: [Building]) -> HouseModifiers {
        var modifiers = HouseModifiers.none
        for source in sources where Self.haveSameOwner(source, house) {
            let distance = Self.footprintDistance(source, house)
            for reach in source.kind.signatureReaches where distance <= reach.tiles {
                switch reach.effect {
                case .smoke: modifiers.smoky = true
                case .energy: modifiers.energised = true
                case .inspiration: modifiers.inspired = true
                case .workshopSpeed: continue
                }
            }
        }
        return modifiers
    }

    /// The recipe `building` works on now: a completed monument has none.
    static func activeRecipe(of building: Building) -> ProductionRecipe? {
        building.isCompletedMonument ? nil : ProductionCatalog.recipe(for: building.kind)
    }

    /// Spec: `age-signatures` / The monument is a project.
    mutating func completeProjectStage(of monument: EntityID, events: inout [WorldEvent]) {
        guard let stages = buildings[monument]?.projectStages else { return }
        let next = stages + 1
        buildings[monument]?.projectStages = next
        if next == Self.monumentStages {
            events.append(.monumentCompleted(building: monument))
        }
    }

    /// Spec: `age-signatures` / Gallery commissions inspire houses.
    mutating func applyCommission(_ id: EntityID, events: inout [WorldEvent]) {
        guard let gallery = buildings[id], gallery.kind == .gallery, gallery.state == .operational,
              gallery.commissionTicksLeft == 0, economy.balance >= Self.commissionCost
        else { return }
        economy.deduct(Self.commissionCost)
        buildings[id]?.commissionTicksLeft = Self.commissionTicks
        events.append(.commissionStarted(building: id))
    }

    /// A completed monument raises its owner's tax by 10 % (design D6).
    /// Every building is the player's until `add-rival-towns` lands.
    func taxWithMonumentBonus(_ amount: Int64) -> Int64 {
        hasCompletedMonument ? amount * 110 / 100 : amount
    }
}
