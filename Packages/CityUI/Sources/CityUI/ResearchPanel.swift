import CityCore
import SwiftUI

/// Rows for the research panel. Spec: `platform-shells` / Research
/// panel.
public struct ResearchPanelModel: Equatable {
    public enum State: Equatable {
        case researched
        case inProgress
        case available
        case locked
    }

    public struct Row: Equatable, Identifiable {
        public let tech: Tech
        public let state: State
        public let cost: Int
        public let progress: Int
        public let prerequisites: String
        public let unlocks: String

        public var id: Tech {
            tech
        }
    }

    public let rows: [Row]
    /// Knowledge waiting for a tech to be chosen.
    public let unspent: Int

    public init(world: World) {
        let research = world.research
        unspent = research.knowledge
        rows = Tech.allCases.map { tech in
            let state: State = if research.isResearched(tech) {
                .researched
            } else if research.current == tech {
                .inProgress
            } else if world.canChooseResearch(tech) {
                .available
            } else {
                .locked
            }
            return Row(
                tech: tech,
                state: state,
                cost: world.researchCost(of: tech),
                progress: research.current == tech ? research.progress : 0,
                prerequisites: Self.requirements(of: tech, in: world),
                unlocks: tech.era.map { "The \($0.displayName) age" }
                    ?? tech.unlocks.filter { $0.isBuildable(in: world.culture) }
                    .map { BuildTool.place($0).displayName }.joined(separator: ", ")
            )
        }
    }

    /// Prerequisite techs, the residents an era tech needs, or the age a
    /// later regular tech waits for.
    static func requirements(of tech: Tech, in world: World) -> String {
        var parts = tech.prerequisites.map(\.displayName)
        if let gate = tech.eraGate {
            parts.append("\(gate.residents) \(gate.tier.displayName(in: world.culture).lowercased())")
        } else if tech.age > world.age {
            parts.append("\(tech.age.displayName) age")
        }
        return parts.joined(separator: ", ")
    }
}

struct ResearchPanelView: View {
    let model: ResearchPanelModel
    let choose: (Tech) -> Void
    let dismiss: () -> Void

    var body: some View {
        NavigationStack {
            List(model.rows) { row in
                Button {
                    choose(row.tech)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(row.tech.displayName).font(.headline)
                            Spacer()
                            Text(stateLabel(row)).font(.caption).foregroundStyle(.secondary)
                        }
                        Text(l10n: "research.unlocks", row.unlocks).font(.caption)
                        if !row.prerequisites.isEmpty {
                            Text(l10n: "research.requires", row.prerequisites).font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if row.state == .inProgress {
                            ProgressView(value: Double(row.progress), total: Double(row.cost))
                        }
                    }
                }
                .disabled(row.state != .available)
            }
            .navigationTitle(GameText.string("research.title"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(GameText.string("common.done"), action: dismiss)
                        .cancelActionHotkey()
                }
            }
        }
    }

    private func stateLabel(_ row: ResearchPanelModel.Row) -> String {
        switch row.state {
        case .researched: GameText.string("research.researched")
        case .inProgress: "\(row.progress)/\(row.cost)"
        case .available: GameText.string("research.cost", row.cost)
        case .locked: GameText.string("research.locked")
        }
    }
}

public extension GameSession {
    /// True while `kind` waits on research or the chapter closes it.
    /// Spec: `platform-shells` / Locked palette entries.
    func isLocked(_ kind: BuildingKind) -> Bool {
        !world.research.isAvailable(kind) || world.chapterRules.closedBuildings.contains(kind)
    }

    /// A drawer tile's caption: its cost, or why it is locked. Spec:
    /// `platform-shells` / Locked palette entries.
    func drawerCaption(for kind: BuildingKind) -> String {
        if world.chapterRules.closedBuildings.contains(kind) {
            return PlacementRejectionText.message(for: .closed)
        }
        if isLocked(kind), let tech = Tech.unlocking(kind) {
            return "Needs \(tech.displayName)"
        }
        return "$\(BuildingCatalog.spec(for: kind).cost)"
    }

    /// True when a later tech replaced `kind`. Spec: `platform-shells` /
    /// Palette hides obsolete buildings.
    func isObsolete(_ kind: BuildingKind) -> Bool {
        kind.obsoletedBy.map(world.research.isResearched) ?? false
    }

    /// Palette entries to leave out. Spec: `platform-shells` / Palette
    /// hides obsolete buildings, Palette hides other cultures' buildings.
    func isHidden(_ kind: BuildingKind) -> Bool {
        isObsolete(kind) || !kind.isBuildable(in: world.culture)
    }

    var isResearchAvailable: Bool {
        !isGameOver
    }

    func chooseResearch(_ tech: Tech) {
        enqueue(.chooseResearch(tech))
    }
}

extension View {
    func researchSheet(isPresented: Binding<Bool>, session: GameSession) -> some View {
        sheet(isPresented: isPresented) {
            ResearchPanelView(
                model: ResearchPanelModel(world: session.world),
                choose: { session.chooseResearch($0) },
                dismiss: { isPresented.wrappedValue = false }
            )
            .hudSheetDetents()
        }
    }
}
