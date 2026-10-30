import Testing
@testable import CityCore
@testable import CityUI

// Market-hub playtest (playtests/2026-10-30-market-hub.md): in the lived seed's food shortage,
// the player's porters fed every house a little, so every house went short at the same draw and
// all of them shrank and regrew. Serving the oldest house first keeps the shortage on one house,
// as when houses drew from the stores in entity order.

@Test("scenario: A shortage falls on the newest house, not on every house")
func aShortageFallsOnTheNewestHouse() {
    var world = UITestSeed.livedTownWorld()
    let houses = world.buildings.values.filter { $0.kind == .house && $0.owner == .player }.map(\.id)
    var changes: [EntityID: Int] = [:]
    var last = Dictionary(uniqueKeysWithValues: houses.map { ($0, world.populations[$0]?.population ?? 0) })
    for _ in 0 ..< 1800 {
        _ = world.tick()
        for id in houses {
            let now = world.populations[id]?.population ?? 0
            if now != last[id] { changes[id, default: 0] += 1 }
            last[id] = now
        }
    }
    let churning = changes.values.filter { $0 >= 4 }.count
    #expect(houses.count >= 3)
    #expect(churning <= 1)
}
