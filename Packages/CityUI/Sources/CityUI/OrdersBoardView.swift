import CityCore
import SwiftUI

/// One order as a card: issuer, title, good, reward, progress and the
/// buttons its state allows. Spec: `platform-shells` / Order board.
struct OrderCardView: View {
    let card: OrdersBoardModel.Card
    let session: GameSession
    let isTV: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if card.isFestival {
                    Image(systemName: "party.popper.fill").font(.caption).foregroundStyle(.orange)
                } else {
                    Circle().fill(Color(hex: card.issuerColourHex)).frame(width: 10, height: 10)
                }
                Text(card.issuerName).font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(card.deadline).font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                GoodIconLoader.image(for: card.good)
                    .resizable()
                    .interpolation(GoodIconLoader.interpolation)
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.title).font(.headline)
                    Text(verbatim: "\(card.quantity) \(GameText.inSentence(card.goodName))")
                        .font(.system(.subheadline, design: .monospaced))
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(card.reward).font(.system(.headline, design: .monospaced))
                    Text(card.favour).font(.caption2).foregroundStyle(.secondary)
                }
            }
            if card.isAccepted {
                ProgressView(value: card.progress).tint(.green)
            }
            Text(card.status).font(.caption).foregroundStyle(.secondary)
            buttons
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            card.isFestival ? Color.orange.opacity(0.12) : Color.primary.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay {
            if card.isAccepted {
                RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor, lineWidth: 1.5)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            String("\(card.issuerName): \(card.title), \(card.quantity) \(card.goodName), \(card.deadline), \(card.reward)")
        )
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            if card.isAccepted {
                if !card.byShip {
                    Button(GameText.string("orders.send")) { session.sendOrder(card.id) }
                        .buttonStyle(.borderedProminent)
                        .disabled(!card.canSend)
                } else {
                    Label(GameText.string("orders.unloadAtPort"), systemImage: "ferry.fill")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if card.canAbandon {
                    Button(GameText.string("orders.abandon"), role: .destructive) { session.abandonOrder(card.id) }
                        .buttonStyle(.borderless)
                }
            } else {
                Button(GameText.string("orders.accept")) { session.acceptOrder(card.id) }
                    .buttonStyle(.borderedProminent)
                    .disabled(!card.canAccept)
                Button(GameText.string("orders.decline")) { session.declineOrder(card.id) }
                    .buttonStyle(.bordered)
            }
        }
        .controlSize(isTV ? .large : .small)
    }
}

/// The favour of each issuer as pills, with the perk in the help text.
struct FavourPillsView: View {
    let rows: [OrdersBoardModel.FavourRow]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 6, alignment: .leading)], alignment: .leading, spacing: 6) {
            ForEach(rows) { row in
                HStack(spacing: 5) {
                    Circle().fill(Color(hex: row.colourHex)).frame(width: 9, height: 9)
                    Text(row.name.replacingOccurrences(of: "The ", with: "")).font(.caption).lineLimit(1)
                    Text(verbatim: "\(row.value)").font(.system(.caption, design: .monospaced)).fontWeight(.semibold)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.06), in: Capsule())
                .help(row.perk)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(GameText.string("orders.a11y.favour", row.name, row.value))
                .accessibilityValue(row.perk)
            }
        }
    }
}

/// The cards and the favour readout, shared by the column and the sheet.
struct OrdersBoardContent: View {
    let session: GameSession
    let isTV: Bool

    var body: some View {
        let board = session.ordersBoard
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                FavourPillsView(rows: board.favour)
                if board.cards.isEmpty {
                    Text(l10n: "orders.empty")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(board.cards) { card in
                    OrderCardView(card: card, session: session, isTV: isTV)
                }
                ForEach(board.favour.filter { $0.step > 0 || $0.value != 0 }) { row in
                    Text(verbatim: "\(row.name): \(row.perk)").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
        .tvScrollFocus()
    }
}

/// The board as a glass column on the trailing edge. Spec: `platform-shells`
/// / Order board layout.
struct OrdersBoardColumn: View {
    let session: GameSession
    let frame: CGRect
    let isTV: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(l10n: "orders.title").font(.title3.weight(.bold))
                Spacer(minLength: 0)
                Button {
                    session.isOrdersPresented = false
                } label: {
                    Image(systemName: "xmark").imageScale(.medium).padding(8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(GameText.string("orders.close"))
                .cancelActionHotkey()
            }
            OrdersBoardContent(session: session, isTV: isTV)
        }
        .padding(14)
        .frame(width: frame.width, height: frame.height, alignment: .topLeading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .tvFocusSection()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(GameText.string("orders.title"))
    }
}

/// The board as a sheet, where there is no room for the column.
struct OrdersBoardSheet: View {
    let session: GameSession

    var body: some View {
        NavigationStack {
            OrdersBoardContent(session: session, isTV: false)
                .padding(.horizontal)
                .navigationTitle(GameText.string("orders.title"))
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(GameText.string("common.done")) { session.isOrdersPresented = false }.cancelActionHotkey()
                    }
                }
        }
    }
}

/// The HUD entry: a capsule with the open count, or on a phone and Apple TV
/// a round button. A dot marks a waiting offer.
struct OrdersChipView: View {
    let chip: OrdersChipModel
    let layout: HUDLayout
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if layout.showsRoundOrdersEntry {
                Image(systemName: "scroll.fill")
                    .imageScale(.large)
                    .padding(8)
                    .background(.thinMaterial, in: Circle())
                    .overlay(alignment: .topTrailing) { badge }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "scroll.fill")
                    Text(l10n: "orders.title").fontWeight(.semibold)
                    Text(verbatim: "\(chip.accepted)/\(OrderRules.maxAccepted)").monospacedDigit()
                }
                .font(.subheadline)
                .padding(.horizontal, 12)
                .frame(minHeight: layout.focusableHeight(32))
                .background(.thinMaterial, in: Capsule())
                .overlay(alignment: .topTrailing) { badge }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(chip.accessibilityLabel)
        .accessibilityIdentifier("hud.ordersChip")
    }

    @ViewBuilder
    private var badge: some View {
        if chip.hasOffer {
            Circle().fill(Color.red).frame(width: 10, height: 10)
                .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.5))
                .accessibilityHidden(true)
        }
    }
}

extension CityRootView {
    /// The chip at the left of the menu buttons; nil without an active calendar.
    @ViewBuilder
    func ordersChip(layout: HUDLayout) -> some View {
        if let chip = session.ordersChip {
            OrdersChipView(chip: chip, layout: layout) { session.toggleOrdersBoard() }
        }
    }
}

extension View {
    /// The board as a sheet where it has no column. Spec: `platform-shells`
    /// / Order board layout.
    func ordersSheet(session: GameSession, presentation: OrderBoardLayout.Presentation) -> some View {
        sheet(isPresented: Binding(
            get: { session.isOrdersPresented && presentation == .sheet },
            set: { if !$0 { session.isOrdersPresented = false } }
        )) {
            OrdersBoardSheet(session: session).hudSheetDetents()
        }
    }
}
