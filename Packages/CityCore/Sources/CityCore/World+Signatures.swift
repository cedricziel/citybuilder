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

/// What a signature building reaches: the counts its inspector shows
/// (design D10).
public struct SignatureCoverage: Hashable, Sendable {
    public var workshops: Int
    public var smokyHouses: Int
    public var energisedHouses: Int
    public var inspiredHouses: Int
    /// Buildings a mead hall relieves of upkeep.
    public var relievedBuildings: Int
    /// Houses a forum taxes.
    public var taxedHouses: Int
    /// Houses a temple garden reaches, whatever their tier.
    public var contemplatingHouses: Int

    public init(
        workshops: Int = 0,
        smokyHouses: Int = 0,
        energisedHouses: Int = 0,
        inspiredHouses: Int = 0,
        relievedBuildings: Int = 0,
        taxedHouses: Int = 0,
        contemplatingHouses: Int = 0
    ) {
        self.workshops = workshops
        self.smokyHouses = smokyHouses
        self.energisedHouses = energisedHouses
        self.inspiredHouses = inspiredHouses
        self.relievedBuildings = relievedBuildings
        self.taxedHouses = taxedHouses
        self.contemplatingHouses = contemplatingHouses
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

    /// True once `owner`'s monument has completed every project stage.
    func hasCompletedMonument(of owner: Owner) -> Bool {
        buildings.values.contains { $0.isCompletedMonument && $0.owner == owner }
    }
}

public extension Building {
    var isCompletedMonument: Bool {
        kind == .monument && projectStages >= World.monumentStages
    }
}

public extension World {
    /// Operational buildings of `source`'s owner that `source` reaches,
    /// once per effect that applies to them, whether or not `source` is
    /// active. `source` may be a placement ghost that is not in the world.
    static func signatureTargets(
        of source: Building,
        among buildings: some Sequence<Building>
    ) -> [(target: Building, effect: SignatureEffect)] {
        var result: [(target: Building, effect: SignatureEffect)] = []
        for target in buildings where target.state == .operational && target.id != source.id {
            guard haveSameOwner(source, target) else { continue }
            let distance = footprintDistance(source, target)
            for reach in source.kind.signatureReaches where distance <= reach.tiles && isAffected(target.kind, by: reach.effect) {
                result.append((target, reach.effect))
            }
        }
        return result
    }

    /// The counts the inspector shows for `source` (design D10).
    static func signatureCoverage(of source: Building, among buildings: some Sequence<Building>) -> SignatureCoverage {
        var coverage = SignatureCoverage()
        for (_, effect) in signatureTargets(of: source, among: buildings) {
            switch effect {
            case .workshopSpeed: coverage.workshops += 1
            case .smoke: coverage.smokyHouses += 1
            case .energy: coverage.energisedHouses += 1
            case .inspiration: coverage.inspiredHouses += 1
            case .upkeepRelief: coverage.relievedBuildings += 1
            case .marketTax: coverage.taxedHouses += 1
            case .contemplation: coverage.contemplatingHouses += 1
            }
        }
        return coverage
    }

    /// True when a signature `effect` applies to buildings of `kind`.
    static func isAffected(_ kind: BuildingKind, by effect: SignatureEffect) -> Bool {
        switch effect {
        case .workshopSpeed: kind.isWorkshop
        case .upkeepRelief: kind != .meadHall && BuildingCatalog.spec(for: kind).upkeep > 0
        case .smoke, .energy, .inspiration, .marketTax, .contemplation: kind == .house
        }
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
                case .workshopSpeed, .upkeepRelief, .marketTax, .contemplation: continue
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
        guard let gallery = playerBuilding(id, kind: .gallery), gallery.state == .operational,
              gallery.commissionTicksLeft == 0, economy.balance >= Self.commissionCost
        else { return }
        economy.deduct(Self.commissionCost)
        buildings[id]?.commissionTicksLeft = Self.commissionTicks
        events.append(.commissionStarted(building: id))
    }

    /// A completed monument raises its owner's tax by 10 % (design D6).
    func taxWithMonumentBonus(_ amount: Int64, for owner: Owner) -> Int64 {
        hasCompletedMonument(of: owner) ? amount * 110 / 100 : amount
    }
}
