import CityCore
import Testing
@testable import CityRender2D

@Test("each building keeps its variant, and a row of neighbours spreads across all of them")
func variantsAreStableAndSpread() {
    let ids = (1 ... 30).map { EntityID(raw: $0) }
    let picks = ids.map(WindowLights.variant(for:))
    #expect(picks == ids.map(WindowLights.variant(for:)))
    #expect(Set(picks) == Set(0 ..< WindowLights.variants))
    // Ids come in build order; a plain modulo would cycle 0, 1, 2 along a street.
    let cycle = ids.map { Int($0.raw) % WindowLights.variants }
    #expect(picks != cycle)
    #expect(zip(picks, picks.dropFirst()).contains { $0 == $1 })
}

@Test("the lights to try are the building's variant, then a single mask")
func lightsCandidates() {
    let id = EntityID(raw: 7)
    #expect(WindowLights.candidates(stem: "building-house", id: id)
        == ["building-house-lights-\(WindowLights.variant(for: id))", "building-house-lights"])
    #expect(WindowLights.candidates(stem: "building-house", id: nil) == ["building-house-lights"])
}

@Test("night lights file with the building they light")
func lightsStemIsTheBuilding() {
    #expect(TextureFiltering.stem(of: "building-house-tier2-lights-1") == "building-house-tier2")
    #expect(TextureFiltering.stem(of: "building-bakery-lights") == "building-bakery")
    #expect(TextureFiltering.stem(of: "building-house-tier2-modern-east-asian-lights-0") == "building-house-tier2-modern-east-asian")
}

/// The time of day at `hour` (0-24), to the nearest tick.
private func at(_ hour: Double) -> TimeOfDay {
    let fraction = (hour / 24 - TimeOfDay.startFraction + 1).truncatingRemainder(dividingBy: 1)
    return TimeOfDay(tick: UInt64((fraction * Double(TimeOfDay.ticksPerDay)).rounded()))
}

@Test("from two to half past four most houses go dark, one in five stays up")
func mostHousesSleepLate() throws {
    let ids = (1 ... 400).map { EntityID(raw: $0) }
    func asleep(at hour: Double) -> Int {
        ids.count(where: { WindowLights.sleepiness(of: $0, at: at(hour)) == 1 })
    }
    #expect(asleep(at: 0) == 0)
    #expect(asleep(at: 23) == 0)
    #expect(asleep(at: 5) == 0)
    let night = asleep(at: 3)
    #expect(night > 280 && night < 360)
    // The quarter hour before two is a fade, not a switch.
    let sleeper = try #require(ids.first { WindowLights.sleepiness(of: $0, at: at(3)) == 1 })
    let halfway = WindowLights.sleepiness(of: sleeper, at: at(2.0 - 0.125))
    #expect(abs(halfway - 0.5) < 0.05)
    // Dark through 4:30, then the quarter hour after it fades back, mirroring the start.
    #expect(WindowLights.sleepiness(of: sleeper, at: at(2.05)) == 1)
    #expect(WindowLights.sleepiness(of: sleeper, at: at(4.45)) == 1)
    #expect(abs(WindowLights.sleepiness(of: sleeper, at: at(4.5 + 0.125)) - 0.5) < 0.05)
    #expect(WindowLights.sleepiness(of: sleeper, at: at(4.75)) == 0)
}
