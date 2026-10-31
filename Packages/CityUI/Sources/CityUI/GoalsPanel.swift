import CityCore
import SwiftUI

/// Rows for the scenario goals panel: goals, bonus goals, and in a chapter
/// the time left and any rival race. Spec: `platform-shells` / Goals panel
/// and win sheet, Goals panel shows bonus goals and limits.
public struct GoalsPanelModel: Equatable {
    public struct Row: Equatable, Identifiable {
        public let id: Int
        public let text: String
        public let isMet: Bool
    }

    /// A rival race: the player's standing beside the leading rival's.
    public struct Race: Equatable {
        public let title: String
        public let player: String
        public let rival: String
    }

    public let rows: [Row]
    public let bonusRows: [Row]
    /// "1 year, 2 seasons left" before the deadline.
    public let deadline: String?
    public let race: Race?

    public init(world: World) {
        let rows = world.goals.enumerated().map { index, state in
            (state.isBonus, Row(id: index, text: Self.text(for: state, in: world), isMet: state.isMet))
        }
        self.rows = rows.filter { !$0.0 }.map(\.1)
        bonusRows = rows.filter(\.0).map(\.1)
        let lose = world.loseConditions.map(\.condition)
        deadline = lose.lazy.compactMap { condition -> Int? in
            if case let .deadline(year) = condition { return year }
            return nil
        }.first.map { ChapterText.timeLeft(until: $0, from: world.date) }
        race = world.loseConditions.lazy.compactMap { Self.race($0, in: world) }.first
    }

    static func text(for state: GoalState, in world: World) -> String {
        let text = text(for: state.goal, in: world)
        guard state.holdsForSeason, !state.isMet else { return text }
        return text + (state.heldSince == nil ? GameText.string("goal.holdSeason") : GameText.string("goal.holding"))
    }

    static func text(for goal: Goal, in world: World) -> String {
        let progress = world.progress(toward: goal)
        let count = "\(progress.current)/\(progress.target)"
        let amount = "\(ChapterText.money(progress.current))/\(ChapterText.money(progress.target))"
        switch goal {
        case let .population(_, tier):
            let label = tier == .peasants ? GameText.string("goalsPanel.residents") : tier.displayName(in: world.culture)
            return "\(label) \(count)"
        case let .age(age):
            return GameText.string("goal.age", age.displayName)
        case let .stock(good, _):
            return "\(GoodsCatalog.spec(for: good).displayName) \(count)"
        case .outgrowRivals:
            return GameText.string("goalsPanel.outgrow", count)
        case .orders:
            return GameText.string("goalsPanel.orders", count)
        case let .buildings(kind, _):
            return "\(kind.displayName) \(count)"
        case .signatureProjects:
            return GameText.string("goalsPanel.signature", count)
        case let .research(tech):
            return GameText.string("goal.research", tech.displayName)
        case .treasury:
            return GameText.string("goalsPanel.treasury", amount)
        case .netIncome:
            return GameText.string("goalsPanel.netIncome", amount)
        case .tradeEarnings:
            return GameText.string("goalsPanel.trade", amount)
        case let .landedByShip(good, _):
            return GameText.string("goalsPanel.landed", GoodsCatalog.spec(for: good).displayName, count)
        }
    }

    /// The race while it can still be lost: the player's standing and the
    /// leading rival's, measured the same way.
    static func race(_ state: LoseConditionState, in world: World) -> Race? {
        guard case let .rivalRace(target) = state.condition, !state.settled else { return nil }
        switch target {
        case let .age(age):
            let need = age.rivalResidents
            let standing = { (rival: RivalTown) in rival.age >= age ? need : min(world.population(of: rival.owner), need) }
            guard let leader = world.rivals.max(by: { (standing($0), -Int($0.id)) < (standing($1), -Int($1.id)) }) else {
                return nil
            }
            return Race(
                title: GameText.string("race.firstToAge", age.displayName),
                player: GameText.string("race.youAge", world.age.displayName),
                rival: "\(leader.name) \(standing(leader))/\(need)"
            )
        case let .population(count, tier):
            let standing = { (owner: Owner) in world.residents(of: owner, atLeast: tier) }
            guard let leader = world.rivals.max(by: { (standing($0.owner), -Int($0.id)) < (standing($1.owner), -Int($1.id)) })
            else { return nil }
            return Race(
                title: GameText.string("race.firstToPopulation", count),
                player: GameText.string("race.youCount", standing(.player), count),
                rival: "\(leader.name) \(standing(leader.owner))/\(count)"
            )
        }
    }
}

struct GoalsPanelView: View {
    let model: GoalsPanelModel
    let done: () -> Void

    private func goalRow(_ row: GoalsPanelModel.Row) -> some View {
        Label(row.text, systemImage: row.isMet ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(row.isMet ? .green : .primary)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(model.rows) { row in goalRow(row) }
                }
                if !model.bonusRows.isEmpty {
                    Section(GameText.string("goals.bonusHeader")) {
                        ForEach(model.bonusRows) { row in goalRow(row) }
                    }
                }
                if let race = model.race {
                    Section(race.title) {
                        LabeledContent(race.player, value: race.rival)
                    }
                }
                if let deadline = model.deadline {
                    Section {
                        Label(deadline, systemImage: "hourglass").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(GameText.string("goals.title"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(GameText.string("common.done"), action: done).cancelActionHotkey() }
            }
        }
    }
}

struct ScenarioWonView: View {
    let keepPlaying: () -> Void
    let quitToTitle: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "laurel.leading").font(.largeTitle)
            Text(l10n: "goals.scenarioComplete").font(.title.bold())
            Text(l10n: "goals.scenarioCompleteText")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(GameText.string("goals.keepPlaying"), action: keepPlaying).buttonStyle(.borderedProminent).cancelActionHotkey()
            if let quitToTitle {
                Button(GameText.string("pause.quitToTitle"), action: quitToTitle)
            }
        }
        .padding(32)
    }
}

extension CityRootView {
    @ViewBuilder
    var goalsButton: some View {
        if !session.world.goals.isEmpty {
            Button {
                goalsPresented = true
            } label: {
                Image(systemName: "flag.checkered")
                    .hudIconFont()
                    .padding(8)
                    .background(.thinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(GameText.string("goals.title"))
        }
    }
}

extension View {
    func goalsSheets(session: GameSession, goalsPresented: Binding<Bool>, onQuitToTitle: (() -> Void)?) -> some View {
        sheet(isPresented: goalsPresented) {
            GoalsPanelView(model: GoalsPanelModel(world: session.world)) { goalsPresented.wrappedValue = false }
                .hudSheetDetents()
        }
        .sheet(isPresented: Binding(get: { session.isWinSheetPresented }, set: { session.isWinSheetPresented = $0 })) {
            ScenarioWonView(keepPlaying: { session.isWinSheetPresented = false }, quitToTitle: onQuitToTitle)
        }
    }
}
