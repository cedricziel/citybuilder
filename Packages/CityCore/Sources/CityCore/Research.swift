import Foundation

/// A researchable advance that unlocks buildings. Spec: `research` /
/// Tech tree. Cases and values are generated from the packs.
extension Tech: Comparable {
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

public extension World {
    /// `tech`'s cost on this world's difficulty, rounded down. Spec:
    /// `research` / Research cost scales with difficulty.
    func researchCost(of tech: Tech) -> Int {
        tech.cost * difficulty.researchCostPercent / 100
    }
}

extension World {
    static let libraryKnowledgeIntervalTicks: UInt64 = 10
    static let residentKnowledgeIntervalTicks: UInt64 = 100

    /// Spec: `research` / Knowledge accumulates, Choosing research.
    mutating func runResearchSystem(signatureSources sources: [Building], events: inout [WorldEvent]) {
        if tickCount.isMultiple(of: Self.libraryKnowledgeIntervalTicks) {
            research.knowledge += buildings.values.count {
                $0.kind == .library && $0.state == .operational && $0.owner == .player
            }
        }
        if tickCount.isMultiple(of: Self.residentKnowledgeIntervalTicks) {
            research.knowledge += populations.reduce(0) { total, entry in
                guard owner(of: entry.key) == .player else { return total }
                return total + residentKnowledge(house: entry.key, population: entry.value, sources: sources)
            }
        }
        guard let tech = research.current else { return }
        research.progress += research.knowledge
        research.knowledge = 0
        let cost = researchCost(of: tech)
        if research.progress >= cost {
            research.knowledge = research.progress - cost
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
