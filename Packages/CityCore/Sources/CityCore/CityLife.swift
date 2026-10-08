import Foundation

/// Time of day, derived from the tick count. Spec: `city-life` / Time
/// of day.
public struct TimeOfDay: Hashable, Sendable {
    public enum Phase: Hashable, Sendable { case night, dawn, day, dusk }

    public static let ticksPerDay: UInt64 = 1200
    public static let nightDarkness = 0.55

    /// 0 is midnight, 0.5 is noon. Tick 0 is `startFraction`.
    public let fraction: Double

    /// Games start at this point of the day, mid-morning, so a new city
    /// is not first seen in the dark.
    public static let startFraction = 0.35

    public init(tick: UInt64) {
        let raw = Double(tick % Self.ticksPerDay) / Double(Self.ticksPerDay) + Self.startFraction
        fraction = raw >= 1 ? raw - 1 : raw
    }

    public var phase: Phase {
        switch fraction {
        case ..<0.2: .night
        case ..<0.3: .dawn
        case ..<0.75: .day
        case ..<0.85: .dusk
        default: .night
        }
    }

    /// 0 by day, `nightDarkness` at night, linear through dawn and dusk.
    public var darkness: Double {
        switch phase {
        case .night: Self.nightDarkness
        case .day: 0
        case .dawn: Self.nightDarkness * (0.3 - fraction) / 0.1
        case .dusk: Self.nightDarkness * (fraction - 0.75) / 0.1
        }
    }
}

/// Given names per culture. Spec: `city-life` / Residents have names.
public enum ResidentNames {
    public static func list(for culture: Culture) -> [String] {
        switch culture {
        case .northernEuropean: northernEuropean
        case .mediterranean: mediterranean
        case .eastAsian: eastAsian
        case .middleEastern: middleEastern
        }
    }

    private static let northernEuropean = ("Astrid Bjorn Greta Hans Ingrid Jakob Karin Lars Magda Nils Olga Per "
        + "Ragna Sven Tilda Ulf Vera Wim Elsa Frode Hilde Ivar Liv Otto").split(separator: " ").map(String.init)

    private static let mediterranean = ("Aurelia Bruno Chiara Dario Elena Fabio Giulia Iacopo Livia Marco Nerina Ottavio "
        + "Paola Quinto Rosa Sandro Tullia Ugo Valeria Zeno Flavia Lucio Marta Silvio").split(separator: " ").map(String.init)

    private static let eastAsian = ("Akiko Bao Chen Daisuke Emi Fang Hana Hiro Jun Kenji Lan Mei "
        + "Min Natsu Ping Ren Sakura Tao Wen Xiu Yuki Yong Zhen Kaito").split(separator: " ").map(String.init)

    private static let middleEastern = ("Amira Bashir Dalia Farid Ghada Hadi Imran Jamila Karim Layla Malik Nadia "
        + "Omar Rania Samir Tariq Yasmin Zayd Hala Idris Leena Nabil Salma Yusuf").split(separator: " ").map(String.init)
}

public extension ResidentNames {
    /// `count` distinct names for a house, chosen from its entity ID so
    /// they survive saves and launches.
    static func names(for house: EntityID, culture: Culture, count: Int) -> [String] {
        let names = list(for: culture)
        var rng = DeterministicRNG(seed: UInt64(house.raw) &* 0x9E37_79B9_7F4A_7C15)
        var picked: [String] = []
        while picked.count < min(count, names.count) {
            let name = names[Int(rng.next() % UInt64(names.count))]
            if !picked.contains(name) { picked.append(name) }
        }
        return picked
    }
}

public extension World {
    func residentNames(for house: EntityID, count: Int) -> [String] {
        ResidentNames.names(for: house, culture: culture, count: count)
    }
}

public extension HousePopulation {
    /// The first unmet need of the tier in `culture`, or nil when content.
    /// Spec: `city-life` / Residents have wishes.
    func wish(in culture: Culture) -> Good? {
        tier.needs(in: culture).first { !isSatisfied($0) }
    }
}
