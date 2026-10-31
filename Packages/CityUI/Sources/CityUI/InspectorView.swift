import CityCore
import SwiftUI

/// Headless-testable inspector model. Given a world snapshot and a
/// selected EntityID (or tile), returns the human-readable bullets the
/// SwiftUI inspector renders.
public struct InspectorViewModel: Sendable {
    public let bullets: [String]
    /// The building's name, such as "House"; nil for an empty tile.
    public let title: String?
    /// A house's tier name, nil for other buildings.
    public let tier: String?
    /// A house's residents over its capacity, 0...1; nil for other buildings.
    public let residentsFill: Double?
    /// The gallery's commission button, nil for other buildings.
    public let commission: CommissionButton?
    /// The caravanserai's export picker, nil for other buildings.
    public let exportPicker: ExportPicker?
    /// The rival owning the building, nil for the player's.
    public let rival: RivalSummary?
    /// A rival port's market, nil elsewhere.
    public let market: RivalMarketSection?
    /// A port of any owner, for Route from here; nil elsewhere.
    public let routeStartPort: EntityID?
    /// What stops the building working, nil when nothing does.
    public let problem: String?
    /// Demolish when it costs money (ruins, a burning building), nil when free.
    public let demolish: DemolishButton?

    public init(
        bullets: [String],
        title: String? = nil,
        tier: String? = nil,
        residentsFill: Double? = nil,
        commission: CommissionButton? = nil,
        exportPicker: ExportPicker? = nil,
        rival: RivalSummary? = nil,
        market: RivalMarketSection? = nil,
        routeStartPort: EntityID? = nil,
        problem: String? = nil,
        demolish: DemolishButton? = nil
    ) {
        self.bullets = bullets
        self.title = title
        self.tier = tier
        self.residentsFill = residentsFill
        self.commission = commission
        self.exportPicker = exportPicker
        self.rival = rival
        self.market = market
        self.routeStartPort = routeStartPort
        self.problem = problem
        self.demolish = demolish
    }

    /// Build an inspector model from a snapshot + a target tile. Returns
    /// an empty model when the tile is unoccupied — the view hides itself.
    public static func make(from snapshot: WorldSnapshot, tile: TileCoordinate, buildings: [EntityID: Building]) -> InspectorViewModel {
        guard let entityID = snapshot.occupiedTiles[tile],
              let building = buildings[entityID]
        else { return InspectorViewModel(bullets: []) }

        let spec = BuildingCatalog.spec(for: building.kind)
        let buildProgress = if building.state == .operational {
            GameText.string("inspector.ready")
        } else {
            GameText.string("inspector.buildTicks", building.ticksSincePlacement, spec.buildDurationTicks)
        }
        let rival = building.owner.rivalID.flatMap(snapshot.rival)
        let culture = snapshot.culture(for: building.owner)
        let issue = snapshot.buildingIssues[entityID]
        var houseLines: [String] = []
        var tier: String?
        var residentsFill: Double?
        if let pop = snapshot.housePopulations[entityID] {
            let capacity = (snapshot.houseModifiers[entityID] ?? .none).capacity(of: pop.tier)
            tier = pop.tier.displayName(in: culture)
            residentsFill = capacity > 0 ? min(1, Double(pop.population) / Double(capacity)) : 0
            let needs = pop.tier.needs(in: culture).map { "\($0.rawValue) \(pop.isSatisfied($0) ? "✓" : "✗")" }
            let modifiers = snapshot.houseModifiers[entityID]
            houseLines = [
                GameText.string("inspector.tier", pop.tier.displayName(in: culture)),
                GameText.string("inspector.residents", pop.population, (modifiers ?? .none).capacity(of: pop.tier)),
                GameText.string("inspector.needs", needs.joined(separator: " · "))
            ] + Self.nextTierLine(after: pop.tier, in: culture) + houseNotes(modifiers)
                + houseMarketLines(house: entityID, population: pop, culture: culture, in: snapshot)
                + residentLines(house: entityID, population: pop, culture: culture) + shortageLine(issue)
        }
        let problem = issue.map(problemText)
        let basics = basicLines(
            for: building, buildProgress: buildProgress, hasRoad: !snapshot.roadDisconnectedBuildings.contains(entityID)
        )
        let reach = inReachLine(for: building.kind, count: snapshot.catchments[entityID]) + hubLines(for: building, in: snapshot)
        let signature = signatureLines(for: building, in: snapshot)
        let problemLines = problem.map { [GameText.string("inspector.problem", $0)] } ?? []
        let fire = fireLines(for: building, in: snapshot) + fireWatchLines(for: building, in: snapshot)
            + physicianLines(for: building, in: snapshot)
        let bullets: [String] = fire + basics + reach + signature + houseLines + problemLines
        return InspectorViewModel(
            bullets: bullets,
            title: title(of: building),
            tier: tier,
            residentsFill: residentsFill,
            // A rival's building is read-only.
            commission: rival == nil ? commissionButton(for: building, balance: snapshot.economy.balance) : nil,
            exportPicker: rival == nil ? exportPicker(for: building) : nil,
            rival: rival,
            market: building.kind == .port ? rival.map(RivalMarketSection.init) : nil,
            routeStartPort: building.kind == .port ? entityID : nil,
            problem: problem,
            demolish: rival == nil ? demolishButton(for: building, balance: snapshot.economy.balance) : nil
        )
    }

    /// Kind, anchor, footprint, state, build progress and road: the Details lines every building has.
    static func basicLines(for building: Building, buildProgress: String, hasRoad: Bool) -> [String] {
        let road = hasRoad ? GameText.string("inspector.road.connected") : GameText.string("inspector.road.none")
        return [
            GameText.string("inspector.kind", building.kind.rawValue),
            GameText.string("inspector.anchor", "\(building.anchor.x)", "\(building.anchor.y)"),
            GameText.string("inspector.footprint", building.footprint.width, building.footprint.height),
            GameText.string("inspector.state", stateName(of: building)),
            GameText.string("inspector.build", buildProgress),
            GameText.string("inspector.road", road)
        ]
    }

    /// Spec: `platform-shells` / Inspector names what stops a building.
    static func problemText(_ issue: BuildingIssue) -> String {
        switch issue {
        case .noRoad: GameText.string("problem.noRoad")
        case .noRouteToStorage: GameText.string("problem.noRouteToStorage")
        case .noMarketInReach: GameText.string("problem.noMarketInReach")
        case .noTreesInReach: GameText.string("problem.noTreesInReach", BuildingKind.lumberjackHut.catchmentRadius ?? 0)
        case .noRoomToPlant: GameText.string("problem.noRoomToPlant", BuildingKind.forester.catchmentRadius ?? 0)
        case let .missingInputs(goods):
            GameText.string("problem.waitingFor", goods.map(goodName).joined(separator: ", "))
        case let .outputStuck(good): GameText.string("problem.outputStuck", goodName(good))
        case let .runningShort(good, _, _):
            if issue.isDeclining {
                GameText.string("problem.shortLeaving", goodName(good))
            } else {
                GameText.string("problem.shortWillLeave", goodName(good))
            }
        }
    }

    /// How long a house has been short of a need out of the intervals it may wait. Spec:
    /// `platform-shells` / The inspector warns of a house about to decline.
    static func shortageLine(_ issue: BuildingIssue?) -> [String] {
        guard case let .runningShort(good, intervals, grace)? = issue else { return [] }
        return [GameText.string("inspector.shortage", goodName(good), min(intervals, grace), grace)]
    }
}

/// SwiftUI inspector panel. Hidden when there is no selection.
public struct InspectorView: View {
    public let viewModel: InspectorViewModel
    let onCommission: () -> Void
    let onPickExport: (Good?) -> Void
    let onStartRoute: (EntityID) -> Void
    let onMarketTrade: (TradeDirection, Good, Int) -> Void
    /// The lines to list; nil lists every bullet.
    let lines: [String]?
    let isFramed: Bool
    /// A player town center's market, shown with the details.
    let townMarket: TownMarketSection?

    public init(
        viewModel: InspectorViewModel,
        lines: [String]? = nil,
        isFramed: Bool = true,
        townMarket: TownMarketSection? = nil,
        onCommission: @escaping () -> Void = {},
        onPickExport: @escaping (Good?) -> Void = { _ in },
        onStartRoute: @escaping (EntityID) -> Void = { _ in },
        onMarketTrade: @escaping (TradeDirection, Good, Int) -> Void = { _, _, _ in }
    ) {
        self.viewModel = viewModel
        self.lines = lines
        self.isFramed = isFramed
        self.townMarket = townMarket
        self.onCommission = onCommission
        self.onPickExport = onPickExport
        self.onStartRoute = onStartRoute
        self.onMarketTrade = onMarketTrade
    }

    public var body: some View {
        if viewModel.bullets.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 4) {
                if let rival = viewModel.rival {
                    Label {
                        Text(rival.name).font(.caption.bold())
                    } icon: {
                        Circle().fill(Color(hex: rival.colour.hex)).frame(width: 10, height: 10)
                    }
                }
                ForEach(lines ?? viewModel.bullets, id: \.self) { line in
                    Text(line).font(.caption.monospaced())
                }
                if let commission = viewModel.commission {
                    Button(commission.title, action: onCommission)
                        .font(.caption)
                        .disabled(!commission.isEnabled)
                }
                if let market = viewModel.market {
                    marketSection(market)
                }
                if let townMarket {
                    TownMarketView(market: townMarket, onTrade: onMarketTrade)
                }
                if let port = viewModel.routeStartPort {
                    Button(GameText.string("inspector.routeFromHere"), systemImage: "point.topleft.down.to.point.bottomright.curvepath") {
                        onStartRoute(port)
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
                if let picker = viewModel.exportPicker {
                    Picker(GameText.string("inspector.export"), selection: Binding(get: { picker.selected }, set: { onPickExport($0) })) {
                        ForEach(picker.options, id: \.self) { option in
                            Text(ExportPicker.title(of: option)).tag(option)
                        }
                    }
                    .font(.caption)
                }
            }
            .padding(isFramed ? 12 : 0)
            .background(
                isFramed ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(.clear),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
        }
    }

    private func marketSection(_ market: RivalMarketSection) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(l10n: "market.title").font(.caption.bold())
            Text(l10n: "market.sells").font(.caption2.bold())
            ForEach(market.sells, id: \.self) { Text($0).font(.caption.monospaced()) }
            Text(l10n: "market.buys").font(.caption2.bold())
            ForEach(market.buys, id: \.self) { Text($0).font(.caption.monospaced()) }
        }
    }
}

extension InspectorViewModel {
    /// The lines the callout shows before Details: residents, needs and
    /// market for a house, otherwise state, road and a hub's reach. Spec:
    /// `platform-shells` / Inspector callout.
    public var keyLines: [String] {
        let keys = (tier == nil ? Self.buildingMarkerKeys : Self.houseMarkerKeys) + Self.sharedMarkerKeys
        return keys.map { Self.marker($0) }.compactMap { marker in bullets.first { $0.hasPrefix(marker) } }
    }

    private static let buildingMarkerKeys = [
        "inspector.state", "inspector.road", "inspector.inReach.trees", "inspector.inReach.grass", "inspector.serves",
        "inspector.porters"
    ]
    private static let houseMarkerKeys = ["inspector.residents", "inspector.needs", "inspector.next", "inspector.stock", "inspector.market"]
    private static let sharedMarkerKeys = [
        "inspector.burning", "inspector.burntDown", "inspector.fireWatch.covers", "inspector.watchman",
        "inspector.physician.keeps", "inspector.physician.burns", "inspector.problem"
    ]
    static var markerKeys: [String] {
        buildingMarkerKeys + houseMarkerKeys + sharedMarkerKeys
    }

    /// A line's marker: its template's text before the first placeholder,
    /// in the player's language, so the callout finds the line in any language.
    static func marker(_ key: String, in language: Language = .current) -> String {
        let template = GameText.string(key, in: language)
        return String(template[..<(template.firstIndex(of: "%") ?? template.endIndex)])
    }

    /// The state the inspector names, ruins counting as their own.
    static func stateName(of building: Building) -> String {
        if building.kind == .ruins { return GameText.string("inspector.stateName.ruins") }
        return switch building.state {
        case .planned: GameText.string("inspector.stateName.planned")
        case .constructing: GameText.string("inspector.stateName.constructing")
        case .operational: GameText.string("inspector.stateName.operational")
        case .burning: GameText.string("inspector.stateName.burning")
        }
    }

    /// What the next tier wants beyond this one's needs, below the top
    /// tier. Spec: `platform-shells` / Inspector callout.
    static func nextTierLine(after tier: HouseTier, in culture: Culture) -> [String] {
        guard let next = tier.next else { return [] }
        let current = Set(tier.needs(in: culture))
        let added = next.needs(in: culture).filter { !current.contains($0) }.map(\.rawValue)
        guard !added.isEmpty else { return [] }
        return [GameText.string("inspector.next", next.displayName(in: culture), added.joined(separator: ", "))]
    }

    /// Trees in reach of a hut, or open grass in reach of a forester.
    /// Spec: `platform-shells` / Forestry in the inspector and while
    /// placing.
    static func inReachLine(for kind: BuildingKind, count: Int?) -> [String] {
        guard let count else { return [] }
        return switch kind {
        case .lumberjackHut: [GameText.string("inspector.inReach.trees", count)]
        case .forester: [GameText.string("inspector.inReach.grass", count)]
        default: []
        }
    }

    /// Up to three named residents with the house's wish. Spec:
    /// `platform-shells` / Inspector introduces residents.
    static func residentLines(house: EntityID, population: HousePopulation, culture: Culture) -> [String] {
        let wish = population.wish(in: culture)
            .map { GameText.string("inspector.wants", goodName($0)) }
            ?? GameText.string("inspector.content")
        let tier = population.tier.displayName(in: culture)
        let count = min(3, Int(population.population))
        return ResidentNames.names(for: house, culture: culture, count: count).map { "\($0) · \(tier) · \(wish)" }
    }
}
