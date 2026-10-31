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

    /// The goods the market sells, the goods the island holds or
    /// produces, and any good traded this season, in catalog order.
    public let rows: [Row]
    /// Goods the market only buys and the island can do nothing with,
    /// such as another culture's luxuries; collapsed under "Other goods".
    public let otherRows: [Row]

    init(quotes: [MarketQuote], reach: MarketReach, balance: Int64, isGameOver: Bool, produced: Set<Good> = []) {
        let all = quotes.map { quote in
            let buyable = quote.good.marketTerms.buyLimit > 0
            let sellable = quote.good.marketTerms.sellLimit > 0
            let sides = [
                buyable ? GameText.string("market.buyQuote", quote.buyPrice, quote.buyLeft) : nil,
                sellable ? GameText.string("market.sellQuote", quote.sellPrice, quote.sellLeft) : nil
            ].compactMap(\.self)
            return Row(
                good: quote.good,
                text: quote.good.displayName + " — " + sides.joined(separator: " · "),
                isBuyable: buyable,
                isSellable: sellable,
                canBuy: !isGameOver && quote.buyLeft > 0 && reach.room[quote.good, default: 0] > 0 && balance >= quote.buyPrice,
                canSell: !isGameOver && quote.sellLeft > 0 && reach.stock[quote.good, default: 0] > 0
            )
        }
        let tradedThisSeason = Set(quotes.filter {
            $0.buyLeft < $0.good.marketTerms.buyLimit || $0.sellLeft < $0.good.marketTerms.sellLimit
        }.map(\.good))
        let isUsable = { (row: Row) in
            row.isBuyable || reach.stock[row.good, default: 0] > 0 || produced.contains(row.good)
                || tradedThisSeason.contains(row.good)
        }
        rows = all.filter(isUsable)
        otherRows = all.filter { !isUsable($0) }
    }
}

public extension GameSession {
    /// The market of the selected town center; nil unless it is the
    /// player's and operational.
    var townMarket: TownMarketSection? {
        guard let tile = selectedTile, let id = world.occupiedTiles[tile], let reach = world.marketReach(at: id),
              let anchor = world.buildings[id]?.anchor
        else {
            return nil
        }
        let tileToIsland = world.tileToIslandMap()
        let produced = tileToIsland[anchor].map { island in
            Set(Good.allCases.filter { world.producesGood(onIsland: island, good: $0, tileToIsland: tileToIsland) })
        } ?? []
        return TownMarketSection(
            quotes: world.marketQuotes, reach: reach, balance: world.economy.balance, isGameOver: isGameOver,
            produced: produced
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
    @State private var showsOtherGoods = false

    var body: some View {
        Section {
            rowViews(market.rows)
            if !market.otherRows.isEmpty {
                // Full width, so Down from any button in the row above
                // reaches it on Apple TV.
                Button {
                    showsOtherGoods.toggle()
                } label: {
                    Text(verbatim: showsOtherGoods
                        ? GameText.string("market.hideOtherGoods")
                        : GameText.string("market.otherGoods", market.otherRows.count))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderless)
                if showsOtherGoods {
                    rowViews(market.otherRows)
                        .panelTransition(.fade)
                }
            }
        } header: {
            Text(l10n: "market.title").font(.caption.bold())
        }
        .panelAnimation(value: showsOtherGoods)
    }

    private func rowViews(_ rows: [TownMarketSection.Row]) -> some View {
        ForEach(rows) { row in
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
            button("market.buyQuantity", .bought, row, isEnabled: row.canBuy)
        }
        if row.isSellable, direction != .bought {
            button("market.sellQuantity", .sold, row, isEnabled: row.canSell)
        }
    }

    private func button(_ key: String, _ direction: TradeDirection, _ row: TownMarketSection.Row, isEnabled: Bool) -> some View {
        ForEach([1, 5], id: \.self) { quantity in
            Button(GameText.string(key, quantity)) { onTrade(direction, row.good, quantity) }
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderless)
                .disabled(!isEnabled)
        }
    }
}
