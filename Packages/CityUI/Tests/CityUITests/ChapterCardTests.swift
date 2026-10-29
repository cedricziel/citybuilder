import Foundation
import Testing
@testable import CityCore
@testable import CityUI

// Scenarios from openspec/changes/add-campaigns (platform-shells / Chapter
// intro and ending cards, Goals panel shows bonus goals and limits).

@MainActor
private func chapterSession(_ id: String = "c2", progress: CampaignProgressModel? = nil) throws -> (TitleScreenViewModel, GameSession) {
    let progress = progress ?? testProgress(won: ["c1"])
    let title = TitleScreenViewModel(saveStore: EmptySaves(), sessionFactory: { GameSession(world: $0) }, campaignProgress: progress)
    let chapter = try #require(progress.chapter(id))
    title.startChapter(chapter, world: World.newGame(chapter: chapter, difficulty: .normal, culture: .mediterranean))
    return try (title, #require(title.committedSession))
}

private struct EmptySaves: SaveStoreFacade {
    func mostRecentSave() throws -> SaveSummary? {
        nil
    }

    func load(gameID _: UUID) throws -> World {
        World.newGame()
    }
}

@MainActor
@Test("scenario: intro pauses the game")
func scenarioIntroPausesTheGame() throws {
    let (_, session) = try chapterSession()
    #expect(session.chapterCard == .intro)
    let content = try #require(ChapterCardContent(session: session))
    #expect(content.eyebrow == "The Long Chronicle · Chapter 2")
    #expect(content.text == "Intro of c2.")
    #expect(content.lines == ["40 residents", "Bonus: Treasury of " + HUDViewModel.formatMoney(1500, locale: .current)])
    #expect(content.facts.first?.label == "Before 1206" && content.facts.first?.value == "5 years, 3 seasons left")
    #expect(content.buttons == [.begin])
    session.step()
    #expect(session.world.tickCount == 0)
    session.dismissChapterCard()
    session.step()
    #expect(session.world.tickCount == 1)
}

@MainActor
@Test("scenario: ending card offers the next chapter")
func scenarioEndingCardOffersTheNextChapter() throws {
    let (title, session) = try chapterSession()
    session.dismissChapterCard()
    session.noteBannerEvents(in: [.scenarioWon])
    #expect(!session.isWinSheetPresented)
    let content = try #require(ChapterCardContent(session: session))
    let next = try #require(title.campaignProgress.chapter("c3"))
    #expect(content.buttons == [.start(next), .keepBuilding])
    #expect(content.eyebrow == "Chapter 2 won · Normal")
    #expect(content.facts.map(\.label) == ["Laurels", "Reward"])
    #expect(title.campaignProgress.status(of: "c2") == .won(ChapterRecord(difficulty: .normal, laurels: 0)))
    session.perform(.start(next))
    #expect(title.committedSession?.currentChapter?.id == "c3")
    #expect(title.committedSession?.chapterCard == .intro)
}

@MainActor
@Test("scenario: the last chapter's ending card goes back to chapter select")
func scenarioTheLastChaptersEndingCardGoesBackToChapterSelect() throws {
    let (title, session) = try chapterSession("c3", progress: testProgress(won: ["c1", "c2"]))
    session.dismissChapterCard()
    session.noteBannerEvents(in: [.scenarioWon])
    let content = try #require(ChapterCardContent(session: session))
    #expect(content.buttons == [.backToChapters, .keepBuilding])
    session.perform(.backToChapters)
    #expect(title.committedSession == nil)
    #expect(title.chapterSelect != nil)
}

@MainActor
@Test("scenario: lost card names the reason")
func scenarioLostCardNamesTheReason() throws {
    let (title, session) = try chapterSession()
    session.dismissChapterCard()
    session.noteBannerEvents(in: [.scenarioLost(.deadline)])
    let content = try #require(ChapterCardContent(session: session))
    #expect(content.title == "The year turned before the goals were met")
    #expect(content.text.contains("“40 residents” unmet"))
    #expect(content.buttons == [.retry, .keepBuilding, .backToChapters])
    let old = session.instanceID
    session.perform(.retry)
    #expect(title.committedSession?.instanceID != old)
    #expect(title.committedSession?.currentChapter?.id == "c2")
    #expect(title.committedSession?.world.culture == .mediterranean)
}

@MainActor
@Test("bankruptcy in a chapter shows one lost card and no game-over banner")
func bankruptcyInAChapterShowsOneCard() throws {
    let (_, session) = try chapterSession()
    session.dismissChapterCard()
    session.world.economy.gameOver = true
    session.noteBannerEvents(in: [.gameOver, .scenarioLost(.bankruptcy)])
    let content = try #require(ChapterCardContent(session: session))
    #expect(content.title == "The treasury ran dry")
    #expect(content.buttons == [.retry, .close, .backToChapters])
    #expect(session.banner == nil)
    session.dismissChapterCard()
    #expect(session.banner?.title == "Bankrupt")
}

@MainActor
@Test("other losses read their reasons, and a standalone scenario keeps its win sheet")
func otherLossesReadTheirReasons() throws {
    let (_, session) = try chapterSession()
    for reason in [LossReason.rivalRace(1), .collapse] {
        session.noteBannerEvents(in: [.scenarioLost(reason)])
        #expect(ChapterCardContent(session: session)?.text.isEmpty == false)
    }
    let standalone = GameSession(world: World.newGame(layout: .singleIsland, seed: 0, culture: .northernEuropean, scenario: .firstHarvest))
    standalone.noteBannerEvents(in: [.scenarioLost(.bankruptcy), .scenarioWon])
    #expect(standalone.chapterCard == nil && standalone.isWinSheetPresented)
    standalone.showChapterIntro()
    #expect(standalone.chapterCard == nil)
    #expect(ChapterCardContent(session: standalone) == nil)
}

@MainActor
@Test("first steps stay hidden in a chapter game")
func firstStepsStayHiddenInAChapterGame() throws {
    let (_, session) = try chapterSession()
    session.refreshFirstSteps()
    #expect(session.firstStepsGuide == nil)
    #expect(GameSession(world: World.newGame()).firstStepsGuide != nil)
}

@MainActor
@Test("a loaded chapter save finds its chapter in the progress model")
func aLoadedChapterSaveFindsItsChapter() throws {
    let progress = testProgress(won: ["c1"])
    let title = TitleScreenViewModel(saveStore: EmptySaves(), sessionFactory: { GameSession(world: $0) }, campaignProgress: progress)
    let chapter = try #require(progress.chapter("c2"))
    title.commit(world: World.newGame(chapter: chapter, difficulty: .hard, culture: .eastAsian))
    #expect(title.committedSession?.currentChapter?.id == "c2")
    title.campaignsRequested()
    #expect(title.chapterSelect != nil)
    title.dismissCampaigns()
    #expect(title.chapterSelect == nil)
}

@Test("scenario: rival race readout")
func scenarioRivalRaceReadout() throws {
    let chapter = testChapter("r1", loseConditions: [.rivalRace(.age(.renaissance)), .deadline(year: 1206)], rivals: 1)
    var world = World.newGame(chapter: chapter, difficulty: .normal, culture: .northernEuropean)
    let rival = try #require(world.rivals.first)
    let have = world.population(of: rival.owner)
    let model = GoalsPanelModel(world: world)
    let need = Age.renaissance.rivalResidents
    #expect(model.race?.rival == "\(rival.name) \(min(have, need))/\(need)")
    #expect(model.race?.title == "First to the Renaissance")
    #expect(model.deadline == "5 years, 3 seasons left")
    #expect(model.bonusRows.count == 1 && model.rows.count == 1)
    let population = testChapter("r2", loseConditions: [.rivalRace(.population(60, atLeast: .peasants))], rivals: 1)
    world = World.newGame(chapter: population, difficulty: .normal, culture: .northernEuropean)
    #expect(GoalsPanelModel(world: world).race?.player == "You 0/60")
    #expect(GoalsPanelModel(world: World.newGame()).race == nil)
}

@Test("a holding goal says it must hold")
func aHoldingGoalSaysItMustHold() {
    var world = World.newGame()
    world.goals = [GoalState(goal: .population(20, atLeast: .peasants), holdsForSeason: true)]
    #expect(GoalsPanelModel(world: world).rows.first?.text == "Residents 0/20 · hold a season")
}
