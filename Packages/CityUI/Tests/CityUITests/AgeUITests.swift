import Testing
@testable import CityCore
@testable import CityUI

// Scenarios from openspec/changes/add-historical-ages.

@MainActor
@Test("scenario: chosen age reaches the world")
func scenarioChosenAgeReachesTheWorld() {
    let dialog = NewGameDialogViewModel()
    #expect(dialog.age == .medieval)
    dialog.age = .industrial
    #expect(dialog.commit()?.age == .industrial)
    dialog.cancel()
    #expect(dialog.age == .medieval)
}

@MainActor
@Test("scenario: medieval banner")
func scenarioMedievalBanner() {
    let session = GameSession(world: World.newGame())
    session.noteBannerEvents(in: [.ageAdvanced(.medieval)])
    #expect(session.banner?.title == "The Medieval age begins")
}

@MainActor
@Test("scenario: quern house leaves the palette")
func scenarioQuernHouseLeavesThePalette() {
    var world = World.newGame()
    world.research.markResearched(.milling)
    let session = GameSession(world: world)
    #expect(!BuildPaletteView.visibleKinds(isHidden: session.isObsolete).contains(.quernHouse))
    let antiquity = GameSession(world: World.newGame(layout: .singleIsland, seed: 0, age: .antiquity))
    #expect(BuildPaletteView.visibleKinds(isHidden: antiquity.isObsolete).contains(.quernHouse))
}

@Test("era tech row shows the age it opens and its residents gate")
func eraTechRowShowsTheAgeItOpensAndItsGate() throws {
    let rows = ResearchPanelModel(world: World.newGame(layout: .singleIsland, seed: 0, age: .antiquity)).rows
    let feudal = try #require(rows.first { $0.tech == .feudalOrder })
    #expect(feudal.unlocks == "The Medieval age")
    #expect(feudal.prerequisites == "20 citizens")
    #expect(feudal.state == .locked)
    #expect(rows.first { $0.tech == .milling }?.prerequisites == "Medieval age")
}
