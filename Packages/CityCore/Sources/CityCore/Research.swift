import Foundation

/// A researchable advance that unlocks buildings. Spec: `research` /
/// Tech tree.
public enum Tech: String, Codable, Sendable, CaseIterable, Comparable {
    case scholarship
    case milling
    case mining
    case metallurgy
    case seafaring

    public var cost: Int {
        switch self {
        case .scholarship: 30
        case .milling: 40
        case .mining: 40
        case .metallurgy: 80
        case .seafaring: 60
        }
    }

    public var prerequisites: [Tech] {
        self == .metallurgy ? [.mining] : []
    }

    public var unlocks: [BuildingKind] {
        switch self {
        case .scholarship: [.library]
        case .milling: [.grainFarm, .windmill, .bakery]
        case .mining: [.mine, .charcoalBurner]
        case .metallurgy: [.smelter, .toolsmith]
        case .seafaring: [.port, .shipyard]
        }
    }

    public var displayName: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
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
    mutating func runResearchSystem() {
        if tickCount.isMultiple(of: Self.libraryKnowledgeIntervalTicks) {
            research.knowledge += buildings.values.count { $0.kind == .library && $0.state == .operational }
        }
        if tickCount.isMultiple(of: Self.residentKnowledgeIntervalTicks) {
            research.knowledge += populations.values
                .filter { $0.tier >= .citizens }
                .reduce(0) { $0 + Int($1.population) }
        }
        guard let tech = research.current else { return }
        research.progress += research.knowledge
        research.knowledge = 0
        if research.progress >= tech.cost {
            research.knowledge = research.progress - tech.cost
            research.progress = 0
            research.current = nil
            research.markResearched(tech)
        }
    }

    /// Tech lock and terrain requirement, checked by `canPlace`.
    func researchOrTerrainRejection(_ kind: BuildingKind, tiles: [TileCoordinate]) -> PlacementRejection? {
        if let tech = Tech.unlocking(kind), !research.isResearched(tech) {
            return .locked(tech)
        }
        if let required = BuildingCatalog.spec(for: kind).requiredTerrain {
            let matching = tiles.count { terrain(at: $0) == required.terrain }
            if matching < required.minTiles { return .needsTerrain(required.terrain) }
        }
        return nil
    }

    mutating func applyChooseResearch(_ tech: Tech) {
        guard research.canChoose(tech) else { return }
        research.knowledge += research.progress
        research.progress = 0
        research.current = tech
    }
}
