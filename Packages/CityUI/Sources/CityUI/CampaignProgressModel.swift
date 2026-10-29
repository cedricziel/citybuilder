import CityCore
import Foundation

/// The player's campaign progress as the screens see it. The app shell
/// backs it with `CityPersistence.CampaignProgressSync`; CityUI never
/// touches storage. Spec: `campaigns` / Campaign progress is a profile
/// record.
@MainActor
@Observable
public final class CampaignProgressModel {
    public private(set) var progress: CampaignProgress
    public let campaigns: [Campaign]
    public let chapters: [Chapter]
    @ObservationIgnored private let persistWin: @Sendable (Chapter, Difficulty, Int) async -> Void

    public init(
        progress: CampaignProgress = CampaignProgress(),
        campaigns: [Campaign] = CampaignCatalog.campaigns,
        chapters: [Chapter] = CampaignCatalog.chapters,
        persistWin: @escaping @Sendable (Chapter, Difficulty, Int) async -> Void = { _, _, _ in }
    ) {
        self.progress = progress
        self.campaigns = campaigns
        self.chapters = chapters
        self.persistWin = persistWin
    }

    public func status(of chapterID: String) -> ChapterStatus {
        progress.status(of: chapterID, campaigns: campaigns, chapters: chapters)
    }

    public func chapter(_ id: String) -> Chapter? {
        chapters.first { $0.id == id }
    }

    /// Records a win here at once and hands it to storage. Returns the next
    /// chapter of its campaign that is now open, if any.
    @discardableResult
    public func recordWin(of chapter: Chapter, difficulty: Difficulty, laurels: Int) -> Chapter? {
        progress.recordWin(of: chapter, difficulty: difficulty, laurels: laurels)
        let persist = persistWin
        Task { await persist(chapter, difficulty, laurels) }
        return nextOpenChapter(after: chapter.id)
    }

    /// The first chapter after `chapterID` in its campaign that is open.
    public func nextOpenChapter(after chapterID: String) -> Chapter? {
        guard let campaign = campaigns.first(where: { $0.chapters.contains(chapterID) }),
              let index = campaign.chapters.firstIndex(of: chapterID)
        else { return nil }
        return campaign.chapters[(index + 1)...].lazy
            .first { self.status(of: $0) == .open }
            .flatMap(chapter)
    }

    /// Merges a copy that changed elsewhere, such as on another device.
    public func merge(_ other: CampaignProgress) {
        progress = progress.merged(with: other)
    }
}
