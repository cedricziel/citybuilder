import CityCore
import Foundation

/// A chapter card: the intro when a chapter starts, the ending in place of
/// the win sheet, and the lost card. Spec: `platform-shells` / Chapter
/// intro and ending cards.
public enum ChapterCard: Equatable, Sendable {
    case intro
    /// `next` is the chapter the win opened, nil when there is none to
    /// open: the action goes back to chapter select.
    case ending(next: Chapter?)
    case lost(LossReason)
}

/// What a card asks the title screen to do.
public enum ChapterAction: Equatable, Sendable {
    case start(Chapter)
    case retry
    case backToChapters
}

public extension GameSession {
    /// The chapter this game plays: the one it started with, else the
    /// catalog's for a loaded save.
    var currentChapter: Chapter? {
        chapter ?? world.chapterRules.chapterID.flatMap { id in
            campaignProgress?.chapter(id) ?? CampaignCatalog.chapter(id)
        }
    }

    /// Shows the intro card; the game waits for the player to begin.
    func showChapterIntro() {
        guard currentChapter != nil else { return }
        chapterCard = .intro
    }

    /// Closes the card; the game ticks again.
    func dismissChapterCard() {
        chapterCard = nil
    }

    /// Runs a card's action through the title screen.
    func perform(_ action: ChapterAction) {
        chapterCard = nil
        onChapterAction?(action)
    }
}

extension GameSession {
    /// In a chapter game a win records progress and shows the ending card
    /// instead of the win sheet. Returns false outside a chapter.
    func noteChapterWin() -> Bool {
        guard let chapter = currentChapter else { return false }
        let next = campaignProgress?.recordWin(of: chapter, difficulty: world.difficulty, laurels: world.laurels)
        chapterCard = .ending(next: next)
        return true
    }

    /// A chapter loss shows the lost card. On bankruptcy it stands in for
    /// the game-over banner, so the player sees one card.
    func noteChapterLoss(_ reason: LossReason) {
        guard currentChapter != nil else { return }
        chapterCard = .lost(reason)
    }
}
