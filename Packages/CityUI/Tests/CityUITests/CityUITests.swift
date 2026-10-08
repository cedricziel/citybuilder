import CityCore
import Foundation
import Testing
@testable import CityUI

@Test("HUDViewModel formats money with currency prefix")
func hudViewModelFormatsMoney() {
    let hud = HUDViewModel(money: 1234, population: 7)
    #expect(hud.formattedMoney(locale: Locale(identifier: "en_US")) == "$1,234")
}

@Test("HUDViewModel formats negative money with sign")
func hudViewModelFormatsNegativeMoney() {
    let hud = HUDViewModel(money: -50, population: 0)
    #expect(hud.formattedMoney(locale: Locale(identifier: "en_US")) == "-$50")
}

@Test("HUDViewModel formats population")
func hudViewModelFormatsPopulation() {
    let hud = HUDViewModel(money: 0, population: 42)
    #expect(hud.formattedPopulation == "Pop. 42")
}

@Test("HUDViewModel reads economy balance + population from snapshot")
func hudViewModelAppliesSnapshot() {
    let world = World.fixtureWithTerrain(width: 4, height: 4, fill: .grass, seed: 1)
    let hud = HUDViewModel()
    hud.apply(world.snapshot())
    #expect(hud.money == Economy.startingBalance)
    #expect(hud.population == 0)
}
