import CityCore
import SwiftUI

/// The Statistics sheet: the season history in four tabs. Spec:
/// `statistics` / The Statistics sheet. Read-only: it enqueues no command.
struct StatisticsSheetView: View {
    let session: GameSession
    let done: () -> Void
    @State private var model: StatisticsModel
    @State private var tab: StatisticsModel.Tab = .goods

    init(session: GameSession, done: @escaping () -> Void) {
        self.session = session
        self.done = done
        _model = State(initialValue: StatisticsModel(world: session.world))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("View", selection: $tab) {
                    ForEach(model.tabs) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal)
                content
            }
            .navigationTitle("Statistics")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done", action: done).cancelActionHotkey() }
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

    @ViewBuilder
    private var content: some View {
        if model.isEmpty {
            ContentUnavailableView(
                "No season has finished yet",
                systemImage: "chart.xyaxis.line",
                description: Text("Come back when the first season ends.")
            )
        } else {
            switch tab {
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
    #if !os(macOS) && !os(tvOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isCompact: Bool {
        sizeClass == .compact
    }
    #else
    private let isCompact = false
    #endif

    private var current: Good? {
        selected.flatMap { good in model.goods.contains { $0.good == good } ? good : nil }
            ?? model.goods.first(where: { $0.stoppedNow > 0 })?.good
            ?? model.goods.first?.good
    }

    var body: some View {
        if model.goods.isEmpty {
            ContentUnavailableView("Nothing made or traded yet", systemImage: "shippingbox")
        } else if isCompact {
            NavigationStack {
                goodsList(selectionPushes: true)
                    .navigationDestination(for: Good.self) { StatisticsGoodDetailView(model: model, good: $0) }
            }
        } else {
            HStack(alignment: .top, spacing: 16) {
                goodsList(selectionPushes: false)
                    .frame(maxWidth: 340)
                if let good = current {
                    ScrollView { StatisticsGoodDetailView(model: model, good: good).padding(.trailing) }
                }
            }
            .padding(.leading)
        }
    }

    private func goodsList(selectionPushes: Bool) -> some View {
        List {
            if model.stoppedProducersNow > 0 {
                Label(
                    "\(model.stoppedProducersNow) producers stopped: output stuck",
                    systemImage: "exclamationmark.octagon.fill"
                )
                .foregroundStyle(.red)
                .font(.footnote.weight(.semibold))
            }
            ForEach(model.goods) { row in
                if selectionPushes {
                    NavigationLink(value: row.good) { StatisticsGoodRowView(row: row, isSelected: false) }
                } else {
                    Button { selected = row.good } label: {
                        StatisticsGoodRowView(row: row, isSelected: row.good == current)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(row.good == current ? .isSelected : [])
                }
            }
        }
    }
}

struct StatisticsGoodRowView: View {
    let row: StatisticsModel.GoodRow
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            GoodIconLoader.image(for: row.good)
                .resizable()
                .interpolation(GoodIconLoader.interpolation)
                .frame(width: 24, height: 24)
            Text(row.name).fontWeight(isSelected ? .semibold : .regular)
            Spacer()
            if row.stoppedNow > 0 {
                Text("\(row.stoppedNow) stopped")
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
        .accessibilityLabel(
            "\(row.name), net \(row.net)" + (row.stoppedNow > 0 ? ", \(row.stoppedNow) producers stopped, output stuck" : "")
        )
    }
}

extension CityRootView {
    var statisticsButton: some View {
        Button {
            session.isStatisticsPresented = true
        } label: {
            Image(systemName: "chart.xyaxis.line")
                .imageScale(.large)
                .padding(8)
                .background(.thinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Statistics")
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
