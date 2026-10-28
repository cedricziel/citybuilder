import CityCore
import Foundation

/// Headless model of the order board. Spec: `platform-shells` / Order
/// board.
public struct OrdersBoardModel: Equatable {
    public struct Card: Equatable, Identifiable {
        public let id: OrderID
        public let issuerName: String
        public let issuerColourHex: String
        public let title: String
        public let good: Good
        public let goodName: String
        public let quantity: Int
        /// "by Autumn 1203".
        public let deadline: String
        public let reward: String
        /// "+2 favour".
        public let favour: String
        public let isAccepted: Bool
        /// A rival's order, filled by ship at its port.
        public let byShip: Bool
        /// 0...1 of the quantity in the stores or delivered; accepted orders only.
        public let progress: Double
        /// What the card says about stock, delivery or when the offer ends.
        public let status: String
        public let canAccept: Bool
        public let canSend: Bool
        public let canAbandon: Bool
    }

    public struct FavourRow: Equatable, Identifiable {
        public let id: String
        public let name: String
        public let colourHex: String
        public let value: Int
        public let step: Int
        public let perk: String
    }

    public let cards: [Card]
    public let favour: [FavourRow]
    public let acceptedCount: Int
    /// The game is over: every control is disabled.
    public let isLocked: Bool

    /// The crown's colour on the board: gold, like the player's own.
    static let crownColourHex = RivalColour.playerHex

    public init(world: World, locale: Locale = .current) {
        isLocked = world.isBankrupt
        acceptedCount = world.acceptedOrderCount
        let locked = isLocked
        let accepted = acceptedCount
        cards = world.boardOrders.map { Self.card($0, in: world, locked: locked, accepted: accepted, locale: locale) }
        favour = Self.favourRows(in: world)
    }

    static func name(of issuer: OrderIssuer, in world: World) -> String {
        switch issuer {
        case .crown: "The Crown"
        case let .rival(id): world.rival(id)?.name ?? "Rival \(id)"
        }
    }

    static func colourHex(of issuer: OrderIssuer, in world: World) -> String {
        switch issuer {
        case .crown: crownColourHex
        case let .rival(id): world.rival(id)?.colour.hex ?? crownColourHex
        }
    }

    /// "by Spring 1203": the date of the season the window ends in.
    static func deadlineText(_ order: Order, in world: World) -> String {
        "by " + world.calendar.date(atTick: order.deadlineTick &- 1).displayText
    }

    private static func card(_ order: Order, in world: World, locked: Bool, accepted: Int, locale: Locale) -> Card {
        let isAccepted = order.state == .accepted
        let byShip = order.issuer != .crown
        let inTransit = world.orders.shipments.filter { $0.order == order.id }.reduce(0) { $0 + $1.amount }
        let dispatch = world.orderDispatch(for: order.id)
        var canSend = false
        if case .ready = dispatch { canSend = true }
        var progress = Double(order.delivered + inTransit) / Double(max(order.quantity, 1))
        var status = ""
        if !isAccepted {
            let ends = world.calendar.date(atTick: order.offerEndsTick &- 1).season.displayName.lowercased()
            status = "Offer ends with \(ends)"
        } else if byShip {
            status = "Delivered \(order.delivered) of \(order.quantity) by ship"
        } else if order.delivered > 0 || inTransit > 0 {
            status = "Delivered \(order.delivered) of \(order.quantity)"
            if inTransit > 0 { status += ", \(inTransit) on the road" }
        } else if case .unavailable(.noRoad) = dispatch {
            status = "No town center to send to"
        } else {
            let stored = world.orderAvailable(for: order.id)
            status = "In stores \(stored) of \(order.quantity)"
            progress = Double(stored) / Double(max(order.quantity, 1))
            if case .unavailable(.late) = dispatch { status += ", too late to send" }
        }
        return Card(
            id: order.id,
            issuerName: name(of: order.issuer, in: world),
            issuerColourHex: colourHex(of: order.issuer, in: world),
            title: order.template.title,
            good: order.good,
            goodName: GoodsCatalog.spec(for: order.good).displayName,
            quantity: order.quantity,
            deadline: deadlineText(order, in: world),
            reward: HUDViewModel.formatMoney(order.reward, locale: locale),
            favour: "+\(order.favourGain) favour",
            isAccepted: isAccepted,
            byShip: byShip,
            progress: isAccepted ? min(1, progress) : 0,
            status: status,
            canAccept: !locked && !isAccepted && accepted < OrderRules.maxAccepted,
            canSend: !locked && canSend,
            canAbandon: !locked && isAccepted && order.delivered == 0 && inTransit == 0
        )
    }

    private static func favourRows(in world: World) -> [FavourRow] {
        let crown = favourRow(
            id: "crown", name: "The Crown", colourHex: crownColourHex, value: world.orders.favour.crown,
            perks: OrderRules.crownResearchDiscountPercent.map { "research costs \($0)% less" }
        )
        let rivals = world.rivals.map { rival in
            favourRow(
                id: "rival-\(rival.id)", name: rival.name, colourHex: rival.colour.hex,
                value: world.orders.favour.value(for: .rival(rival.id)),
                perks: OrderRules.rivalPriceBonusPercent.map { "prices \($0)% better" }
            )
        }
        return [crown] + rivals
    }

    /// `perks` has one phrase per step, the first for step 0 (no perk).
    private static func favourRow(id: String, name: String, colourHex: String, value: Int, perks: [String]) -> FavourRow {
        let step = OrderRules.step(of: value)
        let perk = step == 0
            ? "Next step at \(OrderRules.stepThresholds[0]): \(perks[1])"
            : perks[step].prefix(1).uppercased() + perks[step].dropFirst()
        return FavourRow(id: id, name: name, colourHex: colourHex, value: value, step: step, perk: perk)
    }
}

/// The HUD's orders entry: the open count and whether an offer waits.
/// Spec: `platform-shells` / Orders chip in the HUD.
public struct OrdersChipModel: Equatable {
    public let accepted: Int
    public let hasOffer: Bool

    /// Nil without an active calendar, where no orders are issued.
    public init?(world: World) {
        guard world.calendar.isActive else { return nil }
        accepted = world.acceptedOrderCount
        hasOffer = world.orders.orders.contains { $0.state == .offered }
    }

    /// "Orders 1/2".
    public var label: String {
        "Orders \(accepted)/\(OrderRules.maxAccepted)"
    }

    public var accessibilityLabel: String {
        label.replacingOccurrences(of: "/", with: " of ") + (hasOffer ? ", an offer waits" : "")
    }
}

public extension GameSession {
    var ordersBoard: OrdersBoardModel {
        OrdersBoardModel(world: world)
    }

    var ordersChip: OrdersChipModel? {
        OrdersChipModel(world: world)
    }

    func acceptOrder(_ id: OrderID) {
        enqueue(.acceptOrder(id))
    }

    func declineOrder(_ id: OrderID) {
        enqueue(.declineOrder(id))
    }

    func abandonOrder(_ id: OrderID) {
        enqueue(.abandonOrder(id))
    }

    func sendOrder(_ id: OrderID) {
        enqueue(.dispatchOrder(id))
    }

    /// Opens or closes the board. Where it replaces the inspector, opening
    /// it clears the selection. Spec: `platform-shells` / Order board layout.
    func toggleOrdersBoard() {
        isOrdersPresented.toggle()
        if isOrdersPresented, ordersReplaceInspector {
            selectedTile = nil
        }
    }
}
