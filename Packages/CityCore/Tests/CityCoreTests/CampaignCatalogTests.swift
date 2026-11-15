import Testing
@testable import CityCore

// openspec/changes/add-campaigns (campaigns / Campaigns and chapters are
// game data, Built-in campaigns load).

@Test("scenario: built-in campaigns load")
func scenarioBuiltInCampaignsLoad() throws {
    let chronicle = try #require(CampaignCatalog.campaign("the-long-chronicle"))
    #expect(chronicle.chapters == ["first-fires", "bread-and-stone", "ore-and-anvil", "across-the-water", "the-guild-charter"])
    #expect(chronicle.opensAfter == nil)
    for id in chronicle.chapters {
        let chapter = try #require(CampaignCatalog.chapter(id))
        #expect(!chapter.comingLater, "\(id)")
        #expect(chapter.goals.contains { !$0.isBonus }, "\(id)")
        #expect(chapter.loseConditions.contains { if case .deadline = $0 { true } else { false } }, "\(id)")
        #expect(chapter.intro.count <= 320 && chapter.ending.count <= 320, "\(id)")
    }
}

@Test("the campaign catalog finds chapters and campaigns by id")
func theCampaignCatalogFindsByID() {
    #expect(CampaignCatalog.chapter("first-fires")?.title == "First Fires")
    #expect(CampaignCatalog.chapter("no-such-chapter") == nil)
    let campaign = Campaign(id: "test", title: "Test", chapters: ["test-chapter"])
    #expect(campaign.opensAfter == nil)
    let chapter = Chapter.testChapter(overrides: [.hard: ChapterStartOverride(money: 700)])
    #expect(chapter.overrides[.hard]?.stock == nil)
    let sweep = chapter.sweep
    #expect(chapter.difficulties == Difficulty.allCases)
    #expect(sweep.firstSteps && sweep.market && sweep.order == nil && sweep.kits.isEmpty)
    #expect(!chapter.comingLater)
}
