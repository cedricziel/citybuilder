import CityCore
import SwiftUI

/// What a chapter card shows, worked out from the session so tests read
/// it without a view. Spec: `platform-shells` / Chapter intro and ending
/// cards.
public struct ChapterCardContent: Equatable {
    public enum Button: Equatable {
        case begin
        case start(Chapter)
        case backToChapters
        case retry
        case keepBuilding
        case close
    }

    public struct Fact: Equatable {
        public let label: String
        public let value: String
    }

    public let eyebrow: String
    public let title: String
    public let text: String
    /// Intro: the goals, then the bonus goals marked as such.
    public let lines: [String]
    /// Ending: laurels and the reward. Intro: the deadline.
    public let facts: [Fact]
    public let buttons: [Button]
    /// The intro and ending show the chapter's map; the lost card is small.
    public let showsMap: Bool

    @MainActor
    public init?(session: GameSession) {
        guard let card = session.chapterCard, let chapter = session.currentChapter else { return nil }
        let world = session.world
        let campaigns = session.campaignProgress?.campaigns ?? CampaignCatalog.campaigns
        let campaign = campaigns.first { $0.chapters.contains(chapter.id) }
        let number = (campaign?.chapters.firstIndex(of: chapter.id) ?? 0) + 1
        switch card {
        case .intro:
            eyebrow = [campaign?.title, GameText.string("chapter.number", number)].compactMap(\.self).joined(separator: " · ")
            title = chapter.title
            text = chapter.intro
            lines = world.goals.map { state in
                (state.isBonus ? GameText.string("chapter.bonusPrefix") : "") + ChapterText.goal(state, culture: world.culture)
            }
            facts = world.loseConditions.compactMap { state in
                guard case let .deadline(year) = state.condition else { return nil }
                return Fact(
                    label: GameText.string("chapter.before", ChapterText.year(year)),
                    value: ChapterText.timeLeft(until: year, from: world.date)
                )
            }
            buttons = [.begin]
            showsMap = true
        case let .ending(next):
            eyebrow = GameText.string("chapter.wonEyebrow", number, world.difficulty.displayName)
            title = chapter.title
            text = chapter.ending
            let bonus = world.goals.count(where: \.isBonus)
            lines = []
            facts = [
                Fact(label: GameText.string("chapter.laurels"), value: GameText.string("chapter.laurelsOf", world.laurels, bonus)),
                Fact(label: GameText.string("chapter.reward"), value: ChapterText.reward(chapter.reward))
            ]
            buttons = [next.map(Button.start) ?? .backToChapters, .keepBuilding]
            showsMap = true
        case let .lost(reason):
            eyebrow = GameText.string("chapter.lostEyebrow", number)
            title = ChapterText.lost(reason, in: world)
            text = Self.detail(reason, in: world)
            lines = []
            facts = []
            buttons = [.retry, reason == .bankruptcy ? .close : .keepBuilding, .backToChapters]
            showsMap = false
        }
    }

    private static func detail(_ reason: LossReason, in world: World) -> String {
        switch reason {
        case .deadline:
            guard let unmet = world.goals.first(where: { !$0.isBonus && !$0.isMet }) else {
                return GameText.string("chapter.lostDeadline")
            }
            return GameText.string(
                "chapter.lostDeadlineGoal",
                ChapterText.year(world.date.year),
                ChapterText.goal(unmet, culture: world.culture)
            )
        case .rivalRace:
            return GameText.string("chapter.lostRace")
        case .collapse:
            return GameText.string("chapter.lostCollapse")
        case .bankruptcy:
            return GameText.string("chapter.lostBankrupt")
        }
    }
}

/// The card as a sheet with a map header: the chapter's map drawn like the
/// minimap, from the game's own terrain (canvas option B).
struct ChapterCardView: View {
    let session: GameSession
    let content: ChapterCardContent
    @State private var mapImage: CGImage?

    var body: some View {
        ScrollView {
            ChapterCardBody(content: content, mapImage: mapImage, onTap: tap)
        }
        .frame(idealWidth: 440)
        .task { mapImage = session.minimap.terrainImage ?? Self.map(of: session.world) }
        .tvSheetWidth()
    }

    private func tap(_ button: ChapterCardContent.Button) {
        switch button {
        case .begin, .keepBuilding, .close: session.dismissChapterCard()
        case let .start(next): session.perform(.start(next))
        case .backToChapters: session.perform(.backToChapters)
        case .retry: session.perform(.retry)
        }
    }

    static func map(of world: World) -> CGImage? {
        MinimapTerrainRaster(terrain: world.terrainGrid, mapWidth: world.mapWidth, mapHeight: world.mapHeight).makeImage()
    }
}

/// The card's content: header, text, rows and buttons.
struct ChapterCardBody: View {
    let content: ChapterCardContent
    let mapImage: CGImage?
    var onTap: (ChapterCardContent.Button) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if content.showsMap {
                ChapterMapHeader(image: mapImage)
            }
            VStack(alignment: .leading, spacing: 12) {
                Text(content.eyebrow)
                    .font(.footnote)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Text(content.title)
                    .font(.title.bold())
                    .accessibilityAddTraits(.isHeader)
                Text(content.text)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                if !content.lines.isEmpty || !content.facts.isEmpty {
                    rows
                }
                buttons
            }
            .padding(20)
        }
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 0) {
            let count = content.lines.count + content.facts.count
            ForEach(Array(content.lines.enumerated()), id: \.offset) { index, line in
                Text(line).font(.callout).padding(.vertical, 8)
                if index < count - 1 { Divider() }
            }
            ForEach(Array(content.facts.enumerated()), id: \.offset) { index, fact in
                LabeledContent(fact.label, value: fact.value).font(.callout).padding(.vertical, 8)
                if content.lines.count + index < count - 1 { Divider() }
            }
        }
        .padding(.horizontal, 12)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 10))
    }

    private var buttons: some View {
        VStack(spacing: 8) {
            ForEach(Array(content.buttons.enumerated()), id: \.offset) { index, button in
                if index == 0 {
                    Button { onTap(button) } label: { Text(Self.label(button)).frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                } else {
                    Button { onTap(button) } label: { Text(Self.label(button)).frame(maxWidth: .infinity) }
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(.top, 4)
    }

    static func label(_ button: ChapterCardContent.Button) -> String {
        switch button {
        case .begin: GameText.string("chapter.begin")
        case let .start(next): GameText.string("chapter.next", next.title)
        case .backToChapters: GameText.string("chapter.backToChapters")
        case .retry: GameText.string("chapter.retry")
        case .keepBuilding: GameText.string("chapter.keepBuilding")
        case .close: GameText.string("common.close")
        }
    }
}

/// A chapter's map drawn like the minimap, over the sea.
struct ChapterMapHeader: View {
    let image: CGImage?

    var body: some View {
        ZStack {
            Color(red: 0.23, green: 0.47, blue: 0.69)
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .padding(12)
            }
        }
        .frame(height: 160)
        .frame(maxWidth: .infinity)
        .clipped()
        .accessibilityHidden(true)
    }
}

extension View {
    /// The chapter card sheet: shows while the session holds a card.
    func chapterCardSheet(session: GameSession) -> some View {
        sheet(isPresented: Binding(
            get: { session.chapterCard != nil },
            set: { if !$0 { session.dismissChapterCard() } }
        )) {
            if let content = ChapterCardContent(session: session) {
                ChapterCardView(session: session, content: content)
                    .interactiveDismissDisabled()
            }
        }
    }
}
