import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-campaigns (campaigns / Chapter
// progression, Campaign rewards, Campaign progress is a profile record).
// The campaigns here are test placeholders shaped like the real ones.

private func chapter(_ id: String, comingLater: Bool = false, reward: ChapterReward? = nil) -> Chapter {
    Chapter(
        id: id, title: id, intro: "Intro.", ending: "Ending.", layout: .singleIsland, seed: 1, age: .medieval,
        start: ChapterStart(money: 1000, stock: [:]), goals: [GoalState(goal: .age(.renaissance))],
        reward: reward ?? .banner(id), comingLater: comingLater
    )
}

private struct Fixture {
    let campaigns: [Campaign]
    let chapters: [Chapter]

    init(seaThreeComingLater: Bool = true) {
        campaigns = [
            Campaign(id: "chronicle", title: "The Long Chronicle", chapters: ["c1", "c2", "c3", "c4"]),
            Campaign(id: "sea", title: "The Merchant Sea", chapters: ["s1", "s2", "s3", "s4"], opensAfter: "c3"),
            Campaign(id: "ground", title: "Hard Ground", chapters: ["g1"], opensAfter: "c3")
        ]
        chapters = ["c1", "c2", "c3", "c4", "s1", "s2", "g1", "s4"].map { chapter($0) }
            + [chapter("s3", comingLater: seaThreeComingLater)]
    }

    func status(_ id: String, _ progress: CampaignProgress) -> ChapterStatus {
        progress.status(of: id, campaigns: campaigns, chapters: chapters)
    }

    func win(_ id: String, _ difficulty: Difficulty, laurels: Int = 0, in progress: inout CampaignProgress) {
        guard let chapter = chapters.first(where: { $0.id == id }) else { return }
        progress.recordWin(of: chapter, difficulty: difficulty, laurels: laurels)
    }
}

@Test("scenario: winning opens the next chapter")
func scenarioWinningOpensTheNextChapter() {
    let fixture = Fixture()
    var progress = CampaignProgress()
    #expect(fixture.status("c1", progress) == .open)
    #expect(fixture.status("c2", progress) == .locked(after: "c1"))
    fixture.win("c1", .normal, in: &progress)
    fixture.win("c2", .easy, in: &progress)
    #expect(fixture.status("c3", progress) == .open)
    #expect(fixture.status("c2", progress) == .won(ChapterRecord(difficulty: .easy, laurels: 0)))
}

@Test("scenario: chronicle 3 opens the other campaigns")
func scenarioChronicleThreeOpensTheOtherCampaigns() {
    let fixture = Fixture()
    var progress = CampaignProgress()
    #expect(fixture.status("s1", progress) == .locked(after: "c3"))
    for id in ["c1", "c2", "c3"] {
        fixture.win(id, .normal, in: &progress)
    }
    #expect(fixture.status("s1", progress) == .open)
    #expect(fixture.status("g1", progress) == .open)
}

@Test("scenario: unlocking skips a chapter that is coming later")
func scenarioUnlockingSkipsAChapterThatIsComingLater() {
    let fixture = Fixture()
    var progress = CampaignProgress()
    for id in ["c1", "c2", "c3", "s1", "s2"] {
        fixture.win(id, .normal, in: &progress)
    }
    #expect(fixture.status("s4", progress) == .open)
    #expect(fixture.status("s3", progress) == .comingLater)
}

@Test("scenario: a chapter that becomes available opens")
func scenarioAChapterThatBecomesAvailableOpens() {
    var progress = CampaignProgress()
    let before = Fixture()
    for id in ["c1", "c2", "c3", "s1", "s2"] {
        before.win(id, .normal, in: &progress)
    }
    let after = Fixture(seaThreeComingLater: false)
    #expect(after.status("s3", progress) == .open)
    #expect(after.status("s4", progress) == .locked(after: "s3"))
}

@Test("scenario: normal outranks easy")
func scenarioNormalOutranksEasy() {
    let fixture = Fixture()
    var first = CampaignProgress(), second = CampaignProgress()
    fixture.win("c1", .normal, in: &first)
    fixture.win("c1", .easy, in: &second)
    let merged = first.merged(with: second)
    #expect(merged.won["c1"] == ChapterRecord(difficulty: .normal, laurels: 0))
    #expect(second.merged(with: first) == merged)
}

@Test("scenario: best result is kept")
func scenarioBestResultIsKept() {
    let fixture = Fixture()
    var progress = CampaignProgress()
    fixture.win("c1", .hard, laurels: 1, in: &progress)
    fixture.win("c1", .easy, laurels: 2, in: &progress)
    #expect(progress.won["c1"] == ChapterRecord(difficulty: .hard, laurels: 2))
}

@Test("scenario: merge keeps the best of both devices")
func scenarioMergeKeepsTheBestOfBothDevices() {
    let fixture = Fixture()
    var phone = CampaignProgress(), tablet = CampaignProgress()
    fixture.win("c1", .normal, in: &phone)
    fixture.win("c2", .normal, in: &phone)
    fixture.win("c1", .hard, laurels: 2, in: &tablet)
    let merged = phone.merged(with: tablet)
    #expect(Set(merged.won.keys) == ["c1", "c2"])
    #expect(merged.won["c1"] == ChapterRecord(difficulty: .hard, laurels: 2))
    #expect(merged.rewards == ["banner:c1", "banner:c2"])
}

@Test("the first win grants the chapter's reward once")
func theFirstWinGrantsTheReward() {
    var progress = CampaignProgress()
    let preset = chapter("p1", reward: .mapPreset("Two Shores"))
    let first = progress.recordWin(of: preset, difficulty: .easy, laurels: 0)
    let second = progress.recordWin(of: preset, difficulty: .hard, laurels: 0)
    #expect(first)
    #expect(!second)
    #expect(progress.rewards == ["mapPreset:Two Shores"])
    #expect(ChapterReward.decor("Founder's stone").id == "decor:Founder's stone")
}

@Test("an unknown chapter is locked and progress survives encoding")
func anUnknownChapterIsLockedAndProgressSurvivesEncoding() throws {
    let fixture = Fixture()
    var progress = CampaignProgress()
    #expect(fixture.status("atlantis", progress) == .locked(after: nil))
    #expect(CampaignProgress().status(of: "first-fires") == .locked(after: nil))
    fixture.win("c1", .hard, laurels: 1, in: &progress)
    let decoded = try JSONDecoder().decode(CampaignProgress.self, from: JSONEncoder().encode(progress))
    #expect(decoded == progress)
}
