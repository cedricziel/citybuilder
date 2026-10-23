import CityCore
import Foundation

/// One collection's tax, upkeep and net as the guide shows them.
struct FirstStepsLedger: Equatable {
    let tax: Int64
    let upkeep: Int64

    var net: Int64 {
        tax - upkeep
    }

    var isNegative: Bool {
        net < 0
    }

    static func money(_ amount: Int64) -> String {
        HUDViewModel.formatMoney(amount, locale: .current)
    }
}

struct FirstStep: Equatable {
    let title: String
    let reason: String
    let isMet: Bool
}

/// The first-hour guide: five steps read from the world and the ledger.
/// Spec: `platform-shells` / First-hour guide.
struct FirstStepsGuide: Equatable {
    let steps: [FirstStep]
    let ledger: FirstStepsLedger
    let hasFarm: Bool

    var metCount: Int {
        steps.filter(\.isMet).count
    }

    var isComplete: Bool {
        metCount == steps.count
    }

    static let houses = 3

    init(world: World) {
        var operational: [BuildingKind: Int] = [:]
        for building in world.buildings.values where building.owner == .player && building.state == .operational {
            operational[building.kind, default: 0] += 1
        }
        let owns = { (kind: BuildingKind) in operational[kind, default: 0] > 0 }
        let (tax, upkeep) = world.playerTaxAndUpkeep
        ledger = FirstStepsLedger(tax: tax, upkeep: upkeep)
        hasFarm = owns(.farm)
        steps = [
            FirstStep(title: "Build a farm", reason: "Farms feed residents. Empty houses pay nothing.", isMet: hasFarm),
            FirstStep(
                title: "Make planks: a lumberjack and a sawmill",
                reason: "A house needs 4 planks. The market sells them too.",
                isMet: owns(.lumberjackHut) && owns(.sawmill)
            ),
            FirstStep(
                title: "Build \(Self.houses) houses on a road",
                reason: "Fed residents move in and pay tax.",
                isMet: operational[.house, default: 0] >= Self.houses
            ),
            FirstStep(
                title: "Earn more tax than upkeep",
                reason: "The net above decides your treasury.",
                isMet: tax > 0 && tax >= upkeep
            ),
            FirstStep(
                title: "Sell surplus at the market",
                reason: "Tap the town center when cash runs low.",
                isMet: world.market.sold.values.contains { $0 > 0 }
            )
        ]
    }
}

extension GameSession {
    /// Hides the guide for the rest of the session.
    func hideFirstSteps() {
        isFirstStepsDismissed = true
        refreshFirstSteps()
    }

    /// Recomputes the guide once per tick: shown in the first year with a
    /// step open, until hidden, finished or the game is over. Finishing
    /// dismisses it, so a new season's empty market ledger doesn't bring
    /// it back (design D2).
    func refreshFirstSteps() {
        var guide: FirstStepsGuide?
        if !isFirstStepsDismissed, !isGameOver, world.tickCount < CalendarState.ticksPerYear {
            guide = FirstStepsGuide(world: world)
            if guide?.isComplete == true {
                isFirstStepsDismissed = true
                guide = nil
            }
        }
        if guide != firstStepsGuide { firstStepsGuide = guide }
    }

    /// The tool strip's warning for the armed building while the guide
    /// shows. Spec: `platform-shells` / Tool strip warns while the guide
    /// shows.
    var armedGuideWarning: String? {
        guard case let .place(kind) = selectedTool, let guide = firstStepsGuide else { return nil }
        if kind == .house, !guide.hasFarm { return "No farm yet: residents need food" }
        let upkeep = world.difficulty.scaledUpkeep(BuildingCatalog.spec(for: kind).upkeep)
        return upkeep > 0 ? "Upkeep $\(upkeep) per collection" : nil
    }
}
