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

    /// "minus 24 dollars", for VoiceOver.
    static func spokenMoney(_ amount: Int64) -> String {
        let dollars = "\(abs(amount)) \(abs(amount) == 1 ? "dollar" : "dollars")"
        return amount < 0 ? "minus \(dollars)" : dollars
    }
}

struct FirstStep: Equatable {
    let title: String
    let reason: String
    let isMet: Bool
}

/// The first-hour guide: five steps and one collection's ledger. Spec:
/// `platform-shells` / First-hour guide.
struct FirstStepsGuide: Equatable {
    enum Step: CaseIterable, Hashable {
        case farm, planks, houses, tax, market
    }

    let met: Set<Step>
    let ledger: FirstStepsLedger

    static let houses = 3

    var metCount: Int {
        met.count
    }

    var stepCount: Int {
        Step.allCases.count
    }

    /// The steps in order, with the reasons in `idiom`'s words.
    func steps(idiom: HUDIdiom) -> [FirstStep] {
        Step.allCases.map { step in
            let (title, reason) = Self.text(step, idiom: idiom)
            return FirstStep(title: title, reason: reason, isMet: met.contains(step))
        }
    }

    private static func text(_ step: Step, idiom: HUDIdiom) -> (String, String) {
        switch step {
        case .farm: ("Build a farm", "Farms feed residents. Empty houses pay nothing.")
        case .planks: ("Make planks: a lumberjack and a sawmill", "A house needs 4 planks. The market sells them too.")
        case .houses: ("Build \(houses) houses on a road", "Fed residents move in and pay tax.")
        case .tax: ("Earn more tax than upkeep", "The net above decides your treasury.")
        case .market:
            ("Sell surplus at the market", "\(ToolStripText.verb(for: idiom)) the town center when cash runs low.")
        }
    }

    /// The steps the player's own buildings, ledger and market meet now.
    static func steps(metIn world: World, ledger: FirstStepsLedger) -> Set<Step> {
        var operational: [BuildingKind: Int] = [:]
        var housesOnRoads = 0
        for building in world.buildings.values where building.owner == .player && building.state == .operational {
            operational[building.kind, default: 0] += 1
            if building.kind == .house, world.isRoadConnected(building) { housesOnRoads += 1 }
        }
        let owns = { (kind: BuildingKind) in operational[kind, default: 0] > 0 }
        var met: Set<Step> = []
        if owns(.farm) { met.insert(.farm) }
        if owns(.lumberjackHut), owns(.sawmill) { met.insert(.planks) }
        if housesOnRoads >= houses { met.insert(.houses) }
        if ledger.tax > ledger.upkeep { met.insert(.tax) }
        if world.market.sold.values.contains(where: { $0 > 0 }) { met.insert(.market) }
        return met
    }
}

public extension GameSession {
    /// Hides the guide for the rest of the session.
    func hideFirstSteps() {
        isFirstStepsDismissed = true
        refreshFirstSteps()
    }
}

extension GameSession {
    /// Recomputes the guide once per tick. A met step stays met for the
    /// session; once all are met, or the player hid it, or the game is
    /// over, the guide is gone (design D2).
    func refreshFirstSteps() {
        var guide: FirstStepsGuide?
        if !isFirstStepsDismissed, !isGameOver {
            let (tax, upkeep) = world.playerTaxAndUpkeep
            let ledger = FirstStepsLedger(tax: tax, upkeep: upkeep)
            firstStepsMet.formUnion(FirstStepsGuide.steps(metIn: world, ledger: ledger))
            if firstStepsMet.count == FirstStepsGuide.Step.allCases.count {
                isFirstStepsDismissed = true
            } else {
                guide = FirstStepsGuide(met: firstStepsMet, ledger: ledger)
            }
        }
        if guide != firstStepsGuide { firstStepsGuide = guide }
    }

    /// The tool strip's warning for the armed building while the guide
    /// shows, with the upkeep it would pay at its candidate site. Spec:
    /// `platform-shells` / Tool strip warns while the guide shows.
    func armedGuideWarning(idiom: HUDIdiom) -> String? {
        guard case let .place(kind) = selectedTool, firstStepsGuide != nil else { return nil }
        // The farm step latches, so read the farms standing now: a
        // demolished farm brings the warning back.
        let hasFarm = world.buildings.values.contains {
            $0.owner == .player && $0.kind == .farm && $0.state == .operational
        }
        if kind == .house, !hasFarm { return "No farm yet: residents need food" }
        let upkeep = world.upkeepPerCollection(of: kind, at: armedCandidateSite(idiom: idiom)?.anchor)
        return upkeep > 0 ? "Upkeep \(FirstStepsLedger.money(upkeep)) per collection" : nil
    }
}
