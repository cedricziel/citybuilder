import Foundation

/// A won chapter's best result. Spec: `campaigns` / Chapter progression.
public struct ChapterRecord: Codable, Hashable, Sendable {
    public let difficulty: Difficulty
    public let laurels: Int

    public init(difficulty: Difficulty, laurels: Int) {
        self.difficulty = difficulty
        self.laurels = laurels
    }

    /// The better difficulty (Hard over Normal over Easy) and the more
    /// laurels, each compared on its own.
    func best(with other: ChapterRecord) -> ChapterRecord {
        let rank = { (difficulty: Difficulty) in Difficulty.allCases.firstIndex(of: difficulty) ?? 0 }
        return ChapterRecord(
            difficulty: rank(other.difficulty) > rank(difficulty) ? other.difficulty : difficulty,
            laurels: max(laurels, other.laurels)
        )
    }
}

/// Where a chapter stands for the player.
public enum ChapterStatus: Hashable, Sendable {
    /// Opens once the named chapter is won; nil for a chapter no campaign
    /// lists.
    case locked(after: String?)
    case open
    case won(ChapterRecord)
    /// Shown, never opened, until an update ships it.
    case comingLater
}

/// Campaign progress and rewards: a profile record kept apart from world
/// saves (design D8). Spec: `campaigns` / Campaign progress is a profile
/// record. CityPersistence syncs it through iCloud key-value storage.
public struct CampaignProgress: Codable, Hashable, Sendable {
    /// Best result per won chapter ID.
    public internal(set) var won: [String: ChapterRecord] = [:]
    /// Granted rewards, by `ChapterReward.id`.
    public internal(set) var rewards: Set<String> = []

    public init() {}

    /// Records a win, keeping the best of each result. Returns true when
    /// it is the chapter's first win, which grants its reward.
    @discardableResult
    public mutating func recordWin(of chapter: Chapter, difficulty: Difficulty, laurels: Int) -> Bool {
        let record = ChapterRecord(difficulty: difficulty, laurels: laurels)
        guard let previous = won[chapter.id] else {
            won[chapter.id] = record
            rewards.insert(chapter.reward.id)
            return true
        }
        won[chapter.id] = previous.best(with: record)
        return false
    }

    /// Every chapter won on either copy with the best of each result, and
    /// both copies' rewards. The same whichever copy merges the other.
    public func merged(with other: CampaignProgress) -> CampaignProgress {
        var merged = self
        merged.won.merge(other.won) { $0.best(with: $1) }
        merged.rewards.formUnion(other.rewards)
        return merged
    }

    /// A chapter's status. A coming-later chapter never opens and the
    /// chapter before it is skipped over: the next available chapter opens
    /// on the win before it. A campaign's first chapter opens when its
    /// `opensAfter` chapter is won, or from the start without one.
    public func status(
        of chapterID: String,
        campaigns: [Campaign] = CampaignCatalog.campaigns,
        chapters: [Chapter] = CampaignCatalog.chapters
    ) -> ChapterStatus {
        guard let campaign = campaigns.first(where: { $0.chapters.contains(chapterID) }),
              let index = campaign.chapters.firstIndex(of: chapterID)
        else { return .locked(after: nil) }
        let comingLater = Set(chapters.filter(\.comingLater).map(\.id))
        if comingLater.contains(chapterID) { return .comingLater }
        if let record = won[chapterID] { return .won(record) }
        let key = campaign.chapters[..<index].last { !comingLater.contains($0) } ?? campaign.opensAfter
        guard let key else { return .open }
        return won[key] == nil ? .locked(after: key) : .open
    }
}
