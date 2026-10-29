import Foundation

/// The historical age the city lives in. Spec: `historical-ages`. Cases
/// and values are generated from the packs.
extension Age: Comparable {
    public var next: Age? {
        Age.allCases.first { $0 > self }
    }

    private var index: Int {
        Age.allCases.firstIndex(of: self) ?? 0
    }

    public static func < (lhs: Age, rhs: Age) -> Bool {
        lhs.index < rhs.index
    }
}

extension World {
    /// Residents of `owner` living at `tier` or above.
    public func residents(of owner: Owner = .player, atLeast tier: HouseTier) -> Int {
        populations(of: owner).filter { $0.tier >= tier }.reduce(0) { $0 + Int($1.population) }
    }

    /// Regular techs need their age; era techs need to open the next age
    /// and a big enough city (design D3).
    public func canChooseResearch(_ tech: Tech) -> Bool {
        guard research.canChoose(tech), !chapterRules.closedTechs.contains(tech) else { return false }
        if let era = tech.era {
            guard age.next == era, let gate = tech.eraGate else { return false }
            return residents(atLeast: gate.tier) >= gate.residents
        }
        return tech.age <= age
    }

    /// Moves into `era` and pulls the calendar forward to its start year
    /// when the date is behind (design D4).
    mutating func advanceAge(to era: Age, events: inout [WorldEvent]) {
        guard era > age else { return }
        age = era
        let behind = era.startYear - date.year
        if behind > 0 {
            calendar.startYear += behind
        }
        events.append(.ageAdvanced(era))
    }

    /// Research a new game in `age` starts with (design D5).
    static func initialResearch(for age: Age) -> ResearchState {
        let granted = Tech.allCases.filter { tech in
            if tech == .scholarship { return true }
            if let era = tech.era { return era <= age }
            return tech.age < age
        }
        return ResearchState(researched: granted)
    }
}
