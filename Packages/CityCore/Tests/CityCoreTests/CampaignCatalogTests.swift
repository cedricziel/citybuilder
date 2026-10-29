import Testing
@testable import CityCore

// openspec/changes/add-campaigns (campaigns / Campaigns and chapters are
// game data). The real chapters arrive with M4; until then the catalog
// is empty and lookups find nothing.

@Test("the campaign catalog finds chapters and campaigns by id")
func theCampaignCatalogFindsByID() {
    #expect(CampaignCatalog.chapter("first-fires") == nil)
    #expect(CampaignCatalog.campaign("the-long-chronicle") == nil)
    let campaign = Campaign(id: "test", title: "Test", chapters: ["test-chapter"])
    #expect(campaign.opensAfter == nil)
    let chapter = Chapter.testChapter(overrides: [.hard: ChapterStartOverride(money: 700)])
    #expect(chapter.overrides[.hard]?.stock == nil)
    let sweep = chapter.sweep
    #expect(chapter.difficulties == Difficulty.allCases)
    #expect(sweep.firstSteps && sweep.market && sweep.order == nil && sweep.kits.isEmpty)
    #expect(!chapter.comingLater)
}
