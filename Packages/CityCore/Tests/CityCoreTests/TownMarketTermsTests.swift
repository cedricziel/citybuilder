import Testing
@testable import CityCore

@Test("scenario: Basic goods can be bought")
func basicGoodsCanBeBought() {
    for good in [Good.wood, .planks, .food] {
        #expect(good.marketTerms == MarketTerms(buyLimit: 10, sellLimit: 20), "\(good)")
    }
}

@Test("scenario: Chain goods cannot be bought")
func chainGoodsCannotBeBought() {
    for good in [Good.bread, .tools] + Culture.allCases.map(\.luxuryChain.good) {
        #expect(good.marketTerms == MarketTerms(buyLimit: 0, sellLimit: 20), "\(good)")
    }
}

@Test func everyGoodCanBeSold() {
    #expect(Good.allCases.allSatisfy { $0.marketTerms.sellLimit == 20 })
}
