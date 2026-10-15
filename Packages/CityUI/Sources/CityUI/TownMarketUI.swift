import CityCore
import SwiftUI

/// The market section of a player town center's inspector. Spec:
/// `platform-shells` / Town center market panel (design D6).
public struct TownMarketSection: Equatable, Sendable {
    /// One good: its prices and what is left, and whether Buy and Sell
    /// would move anything.
    public struct Row: Equatable, Sendable, Identifiable {
        public let good: Good
        /// "Wood — buy $6 (10 left) · sell $2 (20 left)"; a side whose
        /// limit is 0 is left out.
        public let text: String
        /// The market sells this good at all, so the row offers Buy.
        public let isBuyable: Bool
        public let isSellable: Bool
        public let canBuy: Bool
        public let canSell: Bool

        public var id: Good {
            good
        }
    }

    public let rows: [Row]

    init(quotes: [MarketQuote], reach: MarketReach, balance: Int64, isGameOver: Bool) {
        rows = quotes.map { quote in
            let buyable = quote.good.marketTerms.buyLimit > 0
            let sellable = quote.good.marketTerms.sellLimit > 0
            let sides = [
                buyable ? "buy $\(quote.buyPrice) (\(quote.buyLeft) left)" : nil,
                sellable ? "sell $\(quote.sellPrice) (\(quote.sellLeft) left)" : nil
            ].compactMap(\.self)
            return Row(
                good: quote.good,
                text: GoodsCatalog.spec(for: quote.good).displayName + " — " + sides.joined(separator: " · "),
                isBuyable: buyable,
                isSellable: sellable,
                canBuy: !isGameOver && quote.buyLeft > 0 && reach.freeSpace > 0 && balance >= quote.buyPrice,
                canSell: !isGameOver && quote.sellLeft > 0 && reach.stock[quote.good, default: 0] > 0
            )
        }
    }
}

public extension GameSession {
    /// The market of the selected town center; nil unless it is the
    /// player's and operational.
    var townMarket: TownMarketSection? {
        guard let tile = selectedTile, let id = world.occupiedTiles[tile], let reach = world.marketReach(at: id) else {
            return nil
        }
        return TownMarketSection(
            quotes: world.marketQuotes, reach: reach, balance: world.economy.balance, isGameOver: isGameOver
        )
    }

    /// Buy or sell `quantity` of `good` at the selected town center.
    func tradeAtMarket(_ direction: TradeDirection, _ good: Good, _ quantity: Int) {
        guard let tile = selectedTile, let id = world.occupiedTiles[tile], world.hasMarket(at: id) else { return }
        enqueue(direction == .bought ? .marketBuy(id, good, quantity) : .marketSell(id, good, quantity))
    }
}

/// The market rows with their Buy and Sell buttons: plain buttons, so
/// they take focus on Apple TV.
struct TownMarketView: View {
    let market: TownMarketSection
    let onTrade: (TradeDirection, Good, Int) -> Void

    var body: some View {
        Section {
            ForEach(market.rows) { row in
                VStack(alignment: .leading, spacing: 2) {
                    rowText(row)
                    // All four buttons on one line where they fit, else Buy
                    // and Sell on a line each.
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) { buttons(row) }
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 10) { buttons(row, only: .bought) }
                            HStack(spacing: 10) { buttons(row, only: .sold) }
                        }
                    }
                }
            }
        } header: {
            Text("Market").font(.caption.bold())
        }
    }

    /// On Apple TV a row whose buttons are all off would hold nothing to
    /// focus, so the remote could never scroll its prices into view; the
    /// text itself takes focus there.
    @ViewBuilder
    private func rowText(_ row: TownMarketSection.Row) -> some View {
        let text = Text(row.text).font(.caption.monospaced()).fixedSize(horizontal: false, vertical: true)
        #if os(tvOS)
        text.focusable()
        #else
        text
        #endif
    }

    @ViewBuilder
    private func buttons(_ row: TownMarketSection.Row, only direction: TradeDirection? = nil) -> some View {
        if row.isBuyable, direction != .sold {
            button("Buy", .bought, row, isEnabled: row.canBuy)
        }
        if row.isSellable, direction != .bought {
            button("Sell", .sold, row, isEnabled: row.canSell)
        }
    }

    private func button(_ verb: String, _ direction: TradeDirection, _ row: TownMarketSection.Row, isEnabled: Bool) -> some View {
        ForEach([1, 5], id: \.self) { quantity in
            Button("\(verb) \(quantity)") { onTrade(direction, row.good, quantity) }
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderless)
                .disabled(!isEnabled)
        }
    }
}
