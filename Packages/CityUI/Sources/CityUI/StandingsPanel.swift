import CityCore
import SwiftUI

/// Headless model of the standings panel. Spec: `platform-shells` /
/// Standings panel.
public struct StandingsPanelModel: Equatable {
    public struct Row: Equatable, Identifiable {
        public let id: Int
        public let name: String
        public let colourHex: String
        public let population: String
        public let age: String
        public let wealth: String
        public let isPlayer: Bool
    }

    public let rows: [Row]

    public init(world: World, locale: Locale = .current) {
        rows = world.standings().enumerated().map { index, standing in
            Row(
                id: index,
                name: standing.name,
                colourHex: standing.colourHex,
                population: "\(standing.population)",
                age: standing.age.displayName,
                wealth: HUDViewModel.formatMoney(standing.wealth, locale: locale),
                isPlayer: standing.owner == .player
            )
        }
    }

    /// The HUD offers the panel only when the world has rivals.
    public static func isAvailable(in world: World) -> Bool {
        !world.rivals.isEmpty
    }
}

struct StandingsPanelView: View {
    let model: StandingsPanelModel
    let done: () -> Void

    var body: some View {
        NavigationStack {
            List(model.rows) { row in
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color(hex: row.colourHex))
                        .frame(width: 12, height: 12)
                    Text(row.name)
                    Spacer()
                    Text(row.population).monospacedDigit()
                    Text(row.age).foregroundStyle(.secondary)
                    Text(row.wealth).monospacedDigit()
                }
                .fontWeight(row.isPlayer ? .bold : .regular)
                .accessibilityElement(children: .combine)
            }
            .navigationTitle("Standings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done", action: done) }
            }
        }
    }
}

extension CityRootView {
    @ViewBuilder
    var standingsButton: some View {
        if StandingsPanelModel.isAvailable(in: session.world) {
            Button {
                standingsPresented = true
            } label: {
                Image(systemName: "trophy.fill")
                    .imageScale(.large)
                    .padding(8)
                    .background(.thinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Standings")
        }
    }
}

extension View {
    func standingsSheet(session: GameSession, isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) {
            StandingsPanelView(model: StandingsPanelModel(world: session.world)) { isPresented.wrappedValue = false }
        }
    }
}

extension Color {
    /// A colour from "#RRGGBB".
    init(hex: String) {
        let value = UInt32(hex.dropFirst(), radix: 16) ?? 0
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
