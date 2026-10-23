import CityCore
import CoreGraphics

/// Which evening of lights a building shows, and when a house goes to bed. Spec: `rendering-2_5d` /
/// Lit windows follow the lights art.
enum WindowLights {
    /// Lights masks per building stem: `<stem>-lights-0` to `-2`.
    static let variants = 3
    /// Lamplight stays a little under full strength, so a lit town reads as evening, not a party.
    static let strength: CGFloat = 0.85
    /// From 2:00 to 4:30 most houses are dark; one in `awakeOneIn` stays up.
    static let sleepFrom = 2.0 / 24, sleepUntil = 4.5 / 24, rampLength = 0.25 / 24
    static let awakeOneIn: UInt64 = 5

    /// A mixed hash of the id, so houses built one after another don't cycle through the variants.
    private static func mix(_ id: EntityID, salt: UInt64) -> UInt64 {
        var rng = DeterministicRNG(seed: UInt64(id.raw) ^ salt)
        return rng.next()
    }

    static func variant(for id: EntityID) -> Int {
        Int(mix(id, salt: 0x6C69_6768_7473) % UInt64(variants))
    }

    /// The names to try, best first: this building's variant, then a single mask.
    static func candidates(stem: String, id: EntityID?) -> [String] {
        let single = "\(stem)-lights"
        guard let id else { return [single] }
        return ["\(single)-\(variant(for: id))", single]
    }

    /// How far a house has gone to bed at `time`: 0 awake, 1 dark, ramping over a quarter hour at
    /// either end of the night. A house that stays up is always 0.
    static func sleepiness(of id: EntityID, at time: TimeOfDay) -> CGFloat {
        guard mix(id, salt: 0x73_6C65_6570) % awakeOneIn != 0 else { return 0 }
        let fraction = time.fraction
        let into = (fraction - (sleepFrom - rampLength)) / rampLength
        let outOf = (sleepUntil - fraction) / rampLength
        return CGFloat(max(0, min(1, into, outOf)))
    }
}
