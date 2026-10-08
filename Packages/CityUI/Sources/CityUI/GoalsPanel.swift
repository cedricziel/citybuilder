import CityCore
import SwiftUI

/// Rows for the scenario goals panel. Spec: `platform-shells` / Goals
/// panel and win sheet.
public struct GoalsPanelModel: Equatable {
    public struct Row: Equatable, Identifiable {
        public let id: Int
        public let text: String
        public let isMet: Bool
    }

    public let rows: [Row]

    public init(world: World) {
        rows = world.goals.enumerated().map { index, state in
            Row(id: index, text: Self.text(for: state.goal, in: world), isMet: state.isMet)
        }
    }

    static func text(for goal: Goal, in world: World) -> String {
        let progress = world.progress(toward: goal)
        switch goal {
        case let .population(_, tier):
            let label = tier == .peasants ? "Residents" : tier.displayName(in: world.culture)
            return "\(label) \(progress.current)/\(progress.target)"
        case let .age(age):
            return "Reach the \(age.displayName) age"
        case let .stock(good, _):
            return "\(GoodsCatalog.spec(for: good).displayName) \(progress.current)/\(progress.target)"
        }
    }
}

struct GoalsPanelView: View {
    let model: GoalsPanelModel
    let done: () -> Void

    var body: some View {
        NavigationStack {
            List(model.rows) { row in
                Label(row.text, systemImage: row.isMet ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(row.isMet ? .green : .primary)
            }
            .navigationTitle("Goals")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done", action: done) }
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
            Text("Scenario complete").font(.title.bold())
            Text("Every goal is met. Keep building, or return to the title screen.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Keep Playing", action: keepPlaying).buttonStyle(.borderedProminent)
            if let quitToTitle {
                Button("Quit to Title", action: quitToTitle)
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
                    .imageScale(.large)
                    .padding(8)
                    .background(.thinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Goals")
        }
    }
}

extension View {
    func goalsSheets(session: GameSession, goalsPresented: Binding<Bool>, onQuitToTitle: (() -> Void)?) -> some View {
        sheet(isPresented: goalsPresented) {
            GoalsPanelView(model: GoalsPanelModel(world: session.world)) { goalsPresented.wrappedValue = false }
        }
        .sheet(isPresented: Binding(get: { session.isWinSheetPresented }, set: { session.isWinSheetPresented = $0 })) {
            ScenarioWonView(keepPlaying: { session.isWinSheetPresented = false }, quitToTitle: onQuitToTitle)
        }
    }
}
