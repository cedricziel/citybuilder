#if os(macOS)
import AppKit
import Foundation
import SwiftUI
import Testing
@testable import CityCore
@testable import CityUI

/// Renders the chapter screens offscreen for the PR's before/after shots
/// when `CHAPTER_SNAPSHOT_DIR` names a folder. Off otherwise.
private let snapshotDirectory = ProcessInfo.processInfo.environment["CHAPTER_SNAPSHOT_DIR"].map(URL.init(fileURLWithPath:))

@MainActor
private func write(_ view: some View, size: CGSize, name: String, to directory: URL) throws {
    let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height)
        .background(Color(nsColor: .windowBackgroundColor)))
    renderer.scale = 2
    let image = try #require(renderer.nsImage)
    let tiff = try #require(image.tiffRepresentation)
    let png = try #require(NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]))
    try png.write(to: directory.appendingPathComponent("\(name).png"))
}

/// A chapter shaped like The Long Chronicle 2 for the shots: placeholder
/// numbers, design D9's card text.
private func breadAndStone(_ id: String, title: String, intro: String, ending: String) -> Chapter {
    Chapter(
        id: id, title: title, intro: intro, ending: ending, layout: .singleIsland, seed: 102, age: .antiquity,
        start: ChapterStart(money: 1000, stock: [.wood: 8, .planks: 6, .food: 4]),
        goals: [
            GoalState(goal: .population(40, atLeast: .peasants)), GoalState(goal: .stock(.bread, 20)),
            GoalState(goal: .signatureProjects(1)), GoalState(goal: .research(.scholarship), isBonus: true),
            GoalState(goal: .population(20, atLeast: .citizens), isBonus: true, holdsForSeason: true)
        ],
        loseConditions: [.deadline(year: -494)], reward: .decor("Founder's stone")
    )
}

@MainActor
@Test("chapter screens render offscreen", .enabled(if: snapshotDirectory != nil))
func chapterScreensRenderOffscreen() async throws {
    let directory = try #require(snapshotDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let chapters = [
        breadAndStone(
            "first-fires",
            title: "First Fires",
            intro: "Smoke rises from one hearth on an empty shore.",
            ending: "A village has taken root."
        ),
        breadAndStone(
            "bread-and-stone", title: "Bread and Stone",
            intro: "The village eats, but it eats porridge. The elders speak of loaves, and of a stone that will outlast everyone here. "
                + "Mill the grain, bake the bread and raise a monument the sea can see.",
            ending: "The monument stands on the hill, raised on bread and sweat. "
                + "Every table has a loaf, and the scholars say a new age is turning."
        ),
        breadAndStone(
            "the-guild-charter",
            title: "The Guild Charter",
            intro: "Merchants will not settle.",
            ending: "The charter is sealed."
        )
    ]
    var won = CampaignProgress()
    won.recordWin(of: chapters[0], difficulty: .normal, laurels: 2)
    let progress = CampaignProgressModel(
        progress: won,
        campaigns: [Campaign(id: "chronicle", title: "The Long Chronicle", chapters: chapters.map(\.id))],
        chapters: chapters
    )
    let title = TitleScreenViewModel(saveStore: SnapshotSaves(), sessionFactory: { GameSession(world: $0) }, campaignProgress: progress)
    title.startChapter(chapters[1], world: World.newGame(chapter: chapters[1], difficulty: .normal, culture: .mediterranean))
    let session = try #require(title.committedSession)
    for (name, card) in [("intro", ChapterCard.intro), ("ending", .ending(next: chapters[2])), ("lost", .lost(.deadline))] {
        session.chapterCard = card
        let content = try #require(ChapterCardContent(session: session))
        let view = ChapterCardBody(content: content, mapImage: ChapterCardView.map(of: session.world))
        try write(
            view.frame(maxHeight: .infinity, alignment: .top),
            size: CGSize(width: 440, height: card == .intro ? 760 : 560),
            name: "card-\(name)",
            to: directory
        )
    }
    let select = ChapterSelectModel(progress: progress, culture: .mediterranean)
    let chapter = try #require(select.selected)
    let detail = await ChapterDetailView(model: select, chapter: chapter, mapImage: select.loadMapImage(for: chapter)) { _ in }
    try write(
        detail.frame(maxHeight: .infinity, alignment: .top),
        size: CGSize(width: 720, height: 900),
        name: "select-detail",
        to: directory
    )
}

private struct SnapshotSaves: SaveStoreFacade {
    func mostRecentSave() throws -> SaveSummary? {
        nil
    }

    func load(gameID _: UUID) throws -> World {
        World.newGame()
    }
}
#endif
