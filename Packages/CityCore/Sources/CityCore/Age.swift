import Foundation

/// The historical age the city lives in. Spec: `historical-ages`.
public enum Age: String, CaseIterable, Codable, Hashable, Sendable, Comparable {
    case antiquity
    case medieval
    case renaissance
    case industrial
    case modern

    public var displayName: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }

    /// Astronomical year: 0 is 1 BC, so −499 is 500 BC.
    public var startYear: Int {
        switch self {
        case .antiquity: -499
        case .medieval: 1200
        case .renaissance: 1450
        case .industrial: 1780
        case .modern: 1910
        }
    }

    public var blurb: String {
        switch self {
        case .antiquity: "Stone towns, hand mills and the first libraries."
        case .medieval: "Timber and tile, windmills and guilds."
        case .renaissance: "Printing, trade and tall stuccoed fronts."
        case .industrial: "Steam, brick and smoking chimneys."
        case .modern: "Electricity and concrete."
        }
    }

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
    /// Residents living at `tier` or above.
    func residents(atLeast tier: HouseTier) -> Int {
        populations(of: .player).filter { $0.tier >= tier }.reduce(0) { $0 + Int($1.population) }
    }

    /// Regular techs need their age; era techs need to open the next age
    /// and a big enough city (design D3).
    public func canChooseResearch(_ tech: Tech) -> Bool {
        guard research.canChoose(tech) else { return false }
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
