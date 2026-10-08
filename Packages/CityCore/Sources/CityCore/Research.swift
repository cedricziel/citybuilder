import Foundation

/// A researchable advance that unlocks buildings. Spec: `research` /
/// Tech tree.
public enum Tech: String, Codable, Sendable, CaseIterable, Comparable {
    case scholarship
    case milling
    case mining
    case metallurgy
    case seafaring
    /// Unlocks every culture's luxury chain. Spec: `culture-content` /
    /// Cultivation unlocks the luxury chain.
    case cultivation
    /// Era techs: each opens the next age. Spec: `research` / Era techs
    /// need a thriving city.
    case feudalOrder = "feudal-order"
    case printingPress = "printing-press"
    case steamPower = "steam-power"
    case electricity

    public var cost: Int {
        switch self {
        case .scholarship: 30
        case .milling: 40
        case .mining: 40
        case .metallurgy: 80
        case .seafaring: 60
        case .cultivation: 50
        case .feudalOrder: 150
        case .printingPress: 250
        case .steamPower: 400
        case .electricity: 600
        }
    }

    public var prerequisites: [Tech] {
        switch self {
        case .metallurgy: [.mining]
        case .printingPress: [.feudalOrder]
        case .steamPower: [.printingPress]
        case .electricity: [.steamPower]
        default: []
        }
    }

    public var unlocks: [BuildingKind] {
        switch self {
        case .scholarship: [.library]
        case .milling: [.windmill]
        case .mining: [.mine, .charcoalBurner]
        case .metallurgy: [.smelter, .toolsmith]
        case .seafaring: [.port, .shipyard]
        case .cultivation: Culture.luxuryBuildings
        case .feudalOrder: [.guildHall]
        case .printingPress: [.gallery]
        case .steamPower: [.steamEngine]
        case .electricity: [.powerPlant]
        }
    }

    /// The age from which a regular tech can be researched.
    public var age: Age {
        switch self {
        case .scholarship: .antiquity
        case .milling, .mining, .metallurgy, .seafaring, .cultivation: .medieval
        case .feudalOrder: .antiquity
        case .printingPress: .medieval
        case .steamPower: .renaissance
        case .electricity: .industrial
        }
    }

    /// The age an era tech opens, nil for regular techs.
    public var era: Age? {
        switch self {
        case .feudalOrder: .medieval
        case .printingPress: .renaissance
        case .steamPower: .industrial
        case .electricity: .modern
        default: nil
        }
    }

    /// Residents the city needs, at a tier or above, to choose an era tech.
    public var eraGate: (tier: HouseTier, residents: Int)? {
        switch self {
        case .feudalOrder: (.citizens, 20)
        case .printingPress: (.merchants, 20)
        case .steamPower: (.merchants, 40)
        case .electricity: (.merchants, 60)
        default: nil
        }
    }

    public var displayName: String {
        switch self {
        case .feudalOrder: "Feudal Order"
        case .printingPress: "Printing Press"
        case .steamPower: "Steam Power"
        default: rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }

    /// The tech that unlocks `kind`, or nil when it is always available.
    public static func unlocking(_ kind: BuildingKind) -> Tech? {
        allCases.first { $0.unlocks.contains(kind) }
    }

    public static func < (lhs: Tech, rhs: Tech) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// City-wide research progress. `researched` is kept sorted so saves
/// encode identically on every run.
public struct ResearchState: Hashable, Codable, Sendable {
    public private(set) var researched: [Tech]
    public internal(set) var current: Tech?
    /// Knowledge not yet spent on a tech.
    public internal(set) var knowledge: Int
    /// Knowledge already spent on `current`.
    public internal(set) var progress: Int

    public init(researched: [Tech], current: Tech? = nil, knowledge: Int = 0, progress: Int = 0) {
        self.researched = researched.sorted()
        self.current = current
        self.knowledge = knowledge
        self.progress = progress
    }

    /// New games start with Scholarship so a library can be built.
    public static let initial = ResearchState(researched: [.scholarship])
    /// Everything researched: test fixtures and migrated older saves.
    public static let everything = ResearchState(researched: Tech.allCases)

    public func isResearched(_ tech: Tech) -> Bool {
        researched.contains(tech)
    }

    public func canChoose(_ tech: Tech) -> Bool {
        !isResearched(tech) && tech.prerequisites.allSatisfy(isResearched)
    }

    public func isAvailable(_ kind: BuildingKind) -> Bool {
        Tech.unlocking(kind).map(isResearched) ?? true
    }

    mutating func markResearched(_ tech: Tech) {
        if !researched.contains(tech) {
            researched = (researched + [tech]).sorted()
        }
    }
}

extension World {
    static let libraryKnowledgeIntervalTicks: UInt64 = 10
    static let residentKnowledgeIntervalTicks: UInt64 = 100

    /// Spec: `research` / Knowledge accumulates, Choosing research.
    mutating func runResearchSystem(events: inout [WorldEvent]) {
        if tickCount.isMultiple(of: Self.libraryKnowledgeIntervalTicks) {
            research.knowledge += buildings.values.count {
                $0.kind == .library && $0.state == .operational && $0.owner == .player
            }
        }
        if tickCount.isMultiple(of: Self.residentKnowledgeIntervalTicks) {
            research.knowledge += residents(atLeast: .citizens)
        }
        guard let tech = research.current else { return }
        research.progress += research.knowledge
        research.knowledge = 0
        if research.progress >= tech.cost {
            research.knowledge = research.progress - tech.cost
            research.progress = 0
            research.current = nil
            research.markResearched(tech)
            if let era = tech.era {
                advanceAge(to: era, events: &events)
            }
        }
    }

    /// Culture rule, tech lock and terrain requirement, checked by
    /// `canPlace`. The culture rule uses the owner's culture; rivals
    /// don't research, so they skip the lock and the obsolete check.
    func researchOrTerrainRejection(
        _ kind: BuildingKind, tiles: [TileCoordinate], for owner: Owner = .player
    ) -> PlacementRejection? {
        if !kind.isBuildable(in: culture(of: owner)), let kindCulture = kind.culture {
            return .wrongCulture(kindCulture)
        }
        if owner == .player {
            if let tech = Tech.unlocking(kind), !research.isResearched(tech) {
                return .locked(tech)
            }
            if let tech = kind.obsoletedBy, research.isResearched(tech) {
                return .obsolete(tech)
            }
        }
        if let required = BuildingCatalog.spec(for: kind).requiredTerrain {
            let matching = tiles.count { terrain(at: $0) == required.terrain }
            if matching < required.minTiles { return .needsTerrain(required.terrain) }
        }
        return nil
    }

    mutating func applyChooseResearch(_ tech: Tech) {
        guard canChooseResearch(tech) else { return }
        research.knowledge += research.progress
        research.progress = 0
        research.current = tech
    }
}
