import CityCore
import SwiftUI

/// The Statistics sheet: the season history in four tabs. Spec:
/// `statistics` / The Statistics sheet. Read-only: it enqueues no command.
struct StatisticsSheetView: View {
    let session: GameSession
    let done: () -> Void
    @State private var model: StatisticsModel

    init(session: GameSession, done: @escaping () -> Void) {
        self.session = session
        self.done = done
        _model = State(initialValue: StatisticsModel(world: session.world))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker(GameText.string("stats.view"), selection: tabBinding) {
                    ForEach(model.tabs) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal)
                content
            }
            .navigationDestination(for: Good.self) { good in
                ScrollView { StatisticsGoodDetailView(model: model, good: good).padding() }
            }
            .background { tabHotkeys }
            .navigationTitle(GameText.string("stats.title"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(GameText.string("common.done"), action: done).cancelActionHotkey() }
            }
        }
        #if os(macOS)
        .frame(minWidth: 820, idealWidth: 880, minHeight: 640, idealHeight: 720)
        #endif
        .task {
            // The history changes once a season; once a second is plenty.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                let fresh = StatisticsModel(world: session.world)
                if fresh != model { model = fresh }
            }
        }
    }

    /// Command-1 to command-4 pick a tab, on the Mac and iPad keyboards.
    private var tabHotkeys: some View {
        ForEach(Array(model.tabs.enumerated()), id: \.offset) { index, tab in
            Button(tab.title) { session.statisticsTab = tab }
                .hotkey(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

    private var tabBinding: Binding<StatisticsModel.Tab> {
        Binding(get: { currentTab }, set: { session.statisticsTab = $0 })
    }

    /// The session's tab, unless this world has no such tab (no rivals).
    private var currentTab: StatisticsModel.Tab {
        model.tabs.contains(session.statisticsTab) ? session.statisticsTab : .goods
    }

    @ViewBuilder
    private var content: some View {
        if model.isEmpty {
            ContentUnavailableView(
                GameText.string("stats.noSeason"),
                systemImage: "chart.xyaxis.line",
                description: Text(l10n: "stats.empty")
            )
        } else {
            switch currentTab {
            case .goods: StatisticsGoodsTab(model: model)
            case .money: StatisticsMoneyTab(model: model)
            case .people: StatisticsPeopleTab(model: model)
            case .rivals: StatisticsRivalsTab(model: model)
            }
        }
    }
}

/// Goods list and detail: side by side on a wide window, a list that
/// pushes the detail on a compact one.
struct StatisticsGoodsTab: View {
    let model: StatisticsModel
    @State private var selected: Good?
    @FocusState private var focusedGood: Good?
    #if !os(macOS) && !os(tvOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isCompact: Bool {
        sizeClass == .compact
    }
    #else
    private let isCompact = false
    #endif

    /// The selected good, if it is still listed, else the one to open on.
    private func resolveCurrent(in goods: [StatisticsModel.GoodRow]) -> Good? {
        if let selected, goods.contains(where: { $0.good == selected }) { return selected }
        return model.defaultGood
    }

    var body: some View {
        let goods = model.goods
        let current = resolveCurrent(in: goods)
        if goods.isEmpty {
            ContentUnavailableView(GameText.string("stats.noGoods"), systemImage: "shippingbox")
        } else if isCompact {
            // The sheet's own stack pushes the detail.
            goodsList(goods, current: current, selectionPushes: true)
        } else {
            HStack(alignment: .top, spacing: 16) {
                goodsList(goods, current: current, selectionPushes: false)
                    .frame(maxWidth: 340)
                if let good = current {
                    ScrollView { StatisticsGoodDetailView(model: model, good: good).padding(.trailing) }
                        .tvScrollFocus()
                }
            }
            .padding(.leading)
        }
    }

    private func goodsList(_ goods: [StatisticsModel.GoodRow], current: Good?, selectionPushes: Bool) -> some View {
        List {
            if model.stoppedProducersNow > 0 {
                Label(
                    GameText.string("stats.producersStopped", model.stoppedProducersNow),
                    systemImage: "exclamationmark.octagon.fill"
                )
                .foregroundStyle(.red)
                .font(.footnote.weight(.semibold))
            }
            ForEach(goods) { row in
                if selectionPushes {
                    NavigationLink(value: row.good) { StatisticsGoodRowView(row: row, isSelected: false) }
                } else {
                    Button { selected = row.good } label: {
                        StatisticsGoodRowView(row: row, isSelected: row.good == current)
                    }
                    .buttonStyle(.plain)
                    .focused($focusedGood, equals: row.good)
                    .accessibilityAddTraits(row.good == current ? .isSelected : [])
                }
            }
        }
        .tvFocusSection()
        .tvDefaultFocus($focusedGood, current)
    }
}

struct StatisticsGoodRowView: View {
    let row: StatisticsModel.GoodRow
    let isSelected: Bool

    private var spokenLabel: String {
        var label = GameText.string("stats.a11y.goodRow", row.name, row.net)
        if row.stoppedNow > 0 {
            label += GameText.string("stats.a11y.rowStopped", row.stoppedNow)
        }
        return label
    }

    var body: some View {
        HStack(spacing: 10) {
            GoodIconLoader.image(for: row.good)
                .resizable()
                .interpolation(GoodIconLoader.interpolation)
                .frame(width: 24, height: 24)
            Text(row.name).fontWeight(isSelected ? .semibold : .regular)
            Spacer()
            if row.stoppedNow > 0 {
                Text(l10n: "stats.stoppedNow", row.stoppedNow)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.red, in: Capsule())
                    .foregroundStyle(.white)
            }
            Text(row.net > 0 ? "+\(row.net)" : "\(row.net)").monospacedDigit().foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(spokenLabel)
    }
}

extension CityRootView {
    var statisticsButton: some View {
        Button {
            session.isStatisticsPresented = true
        } label: {
            Image(systemName: "chart.xyaxis.line")
                .hudIconFont()
                .padding(8)
                .background(.thinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(GameText.string("stats.title"))
        .accessibilityIdentifier("hud.statistics")
    }
}

extension View {
    func statisticsSheet(session: GameSession) -> some View {
        let isPresented = Binding(get: { session.isStatisticsPresented }, set: { session.isStatisticsPresented = $0 })
        return sheet(isPresented: isPresented) {
            StatisticsSheetView(session: session) { isPresented.wrappedValue = false }
                .tvSheetWidth()
        }
    }
}
