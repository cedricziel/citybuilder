import CityCore
import CoreGraphics
import Foundation

/// Behind the chapter select screen: campaigns with their chapters, the
/// chosen chapter and the picks to start it with. Spec: `platform-shells`
/// / Campaigns on the title screen.
@MainActor
@Observable
public final class ChapterSelectModel {
    public enum RowState: Equatable, Sendable {
        case won, open, locked, comingLater
    }

    public struct Row: Identifiable, Equatable, Sendable {
        public let id: String
        public let number: Int
        public let title: String
        public let status: String
        public let state: RowState
    }

    public struct Section: Identifiable, Equatable, Sendable {
        public let id: String
        public let title: String
        /// "2 of 6 won".
        public let tally: String
        public let rows: [Row]
    }

    public let progress: CampaignProgressModel
    public private(set) var selectedID: String?
    /// The chosen chapter's map once it is made; nil while it loads.
    public private(set) var selectedMap: CGImage?
    public var difficulty: Difficulty = .normal
    public var culture: Culture
    /// Chapter maps, made once per chapter for the app's lifetime.
    private static var mapImages: [String: CGImage] = [:]

    public init(progress: CampaignProgressModel, culture: Culture = .northernEuropean) {
        self.progress = progress
        self.culture = culture
        let firstOpen = progress.campaigns.lazy.flatMap(\.chapters).first { progress.status(of: $0) == .open }
        selectedID = firstOpen ?? progress.campaigns.first?.chapters.first
        clampDifficulty()
    }

    /// True while no campaign has a chapter yet: the screen says the
    /// campaigns are on their way.
    public var isEmpty: Bool {
        progress.chapters.isEmpty || progress.campaigns.allSatisfy(\.chapters.isEmpty)
    }

    public var sections: [Section] {
        progress.campaigns.map { campaign in
            let rows = campaign.chapters.enumerated().compactMap { index, id -> Row? in
                guard let chapter = progress.chapter(id) else { return nil }
                let status = progress.status(of: id)
                return Row(
                    id: id, number: index + 1, title: chapter.title,
                    status: ChapterText.status(of: id, status, campaigns: progress.campaigns),
                    state: Self.state(status)
                )
            }
            let won = rows.count { $0.state == .won }
            return Section(id: campaign.id, title: campaign.title, tally: "\(won) of \(rows.count) won", rows: rows)
        }
    }

    public var selected: Chapter? {
        selectedID.flatMap(progress.chapter)
    }

    /// "The Long Chronicle · Chapter 3".
    public var selectedEyebrow: String? {
        guard let id = selectedID, let campaign = progress.campaigns.first(where: { $0.chapters.contains(id) }),
              let index = campaign.chapters.firstIndex(of: id)
        else { return nil }
        return "\(campaign.title) · Chapter \(index + 1)"
    }

    /// The chosen chapter's status line when it can't be started: its key
    /// or "Coming later".
    public var blockedReason: String? {
        guard let id = selectedID else { return nil }
        let status = progress.status(of: id)
        switch status {
        case .open, .won: return nil
        case .locked, .comingLater: return ChapterText.status(of: id, status, campaigns: progress.campaigns)
        }
    }

    public var canStart: Bool {
        selected != nil && blockedReason == nil
    }

    public var difficulties: [Difficulty] {
        selected?.difficulties ?? Difficulty.allCases
    }

    /// The culture picker shows only when the chapter leaves it open.
    public var showsCulturePicker: Bool {
        selected.map { $0.culture == nil } ?? false
    }

    public func select(_ id: String) {
        if id != selectedID { selectedMap = nil }
        selectedID = id
        clampDifficulty()
    }

    /// A new world for the chosen chapter with the picks, or nil when it
    /// can't be started.
    public func makeWorld() -> World? {
        guard canStart, let chapter = selected else { return nil }
        return World.newGame(chapter: chapter, difficulty: difficulty, culture: culture)
    }

    /// Loads the chosen chapter's map. A map that arrives after the
    /// selection moved on is dropped, so one chapter never shows another's.
    public func loadSelectedMap() async {
        guard let id = selectedID, let chapter = selected else { return }
        let image = await loadMapImage(for: chapter)
        guard selectedID == id, !Task.isCancelled else { return }
        selectedMap = image
    }

    /// The chosen chapter's map, drawn like the minimap: made off the main
    /// actor once per chapter, then cached for the app's lifetime.
    public func loadMapImage(for chapter: Chapter) async -> CGImage? {
        if let image = Self.mapImages[chapter.id] { return image }
        let made = await Task.detached(priority: .userInitiated) {
            // Rivals and culture don't change the terrain.
            let world = World.newGame(
                mapPreset: chapter, difficulty: .normal, culture: .northernEuropean, rivals: false, seasonalEvents: false
            )
            let raster = MinimapTerrainRaster(terrain: world.terrainGrid, mapWidth: world.mapWidth, mapHeight: world.mapHeight)
            return MapImage(image: raster.makeImage())
        }.value
        Self.mapImages[chapter.id] = Self.mapImages[chapter.id] ?? made.image
        return Self.mapImages[chapter.id]
    }

    private func clampDifficulty() {
        difficulty = selected?.difficulty(preferring: difficulty) ?? difficulty
    }

    private static func state(_ status: ChapterStatus) -> RowState {
        switch status {
        case .won: .won
        case .open: .open
        case .locked: .locked
        case .comingLater: .comingLater
        }
    }
}

extension Chapter {
    /// `difficulty` when the chapter allows it, else Normal, else its
    /// first.
    func difficulty(preferring difficulty: Difficulty) -> Difficulty {
        if difficulties.contains(difficulty) { return difficulty }
        return difficulties.contains(.normal) ? .normal : difficulties.first ?? .normal
    }
}

/// A finished image handed back from the background task.
private struct MapImage: @unchecked Sendable {
    let image: CGImage?
}
