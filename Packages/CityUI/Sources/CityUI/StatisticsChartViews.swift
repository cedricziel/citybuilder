import Charts
import CityCore
import SwiftUI

private enum StatisticsPalette {
    static let made = Color.blue
    static let used = Color.orange
    static let stuck = Color.red
    static let stored = Color.gray
    static let flowNames: [String] = ["Made", "Used"]
    static let flowColours: [Color] = [made, used]
    static let moneyNames: [String] = ["Tax", "Trade", "Upkeep", "Bought"]
    static let moneyColours: [Color] = [.green, .blue, .orange, .purple]
}

/// Season numbers as x axis marks, labelled from the calendar.
@AxisContentBuilder
private func seasonAxis(_ model: StatisticsModel, _ seasons: [Int]) -> some AxisContent {
    AxisMarks(values: seasons) { value in
        AxisValueLabel(centered: true) {
            if let season = value.as(Int.self) { Text(model.axisLabel(ofSeason: season)).font(.caption2) }
        }
    }
}

/// One bar per season, dodged beside the other flow's.
@ChartContentBuilder
private func flowBars(_ points: [StatisticsModel.Point], name: String) -> some ChartContent {
    ForEach(points) { (point: StatisticsModel.Point) in
        BarMark(x: .value("Season", point.season), y: .value("Units", point.value), width: .fixed(7))
            .position(by: .value("Flow", name))
            .foregroundStyle(by: .value("Flow", name))
    }
}

/// One bar per season and series, stacked, coloured by the series' name.
@ChartContentBuilder
private func moneyBars(_ allSeries: [StatisticsModel.Series]) -> some ChartContent {
    ForEach(allSeries) { (series: StatisticsModel.Series) in
        ForEach(series.points) { (point: StatisticsModel.Point) in
            BarMark(x: .value("Season", point.season), y: .value("Money", point.value), width: .fixed(14))
                .foregroundStyle(by: .value("Kind", series.name))
        }
    }
}

@ChartContentBuilder
private func tierAreas(_ allSeries: [StatisticsModel.Series]) -> some ChartContent {
    ForEach(allSeries) { (series: StatisticsModel.Series) in
        ForEach(series.points) { (point: StatisticsModel.Point) in
            AreaMark(x: .value("Season", point.season), y: .value("Residents", point.value))
                .foregroundStyle(by: .value("Tier", series.name))
        }
    }
}

@ChartContentBuilder
private func townLines(_ allSeries: [StatisticsModel.Series]) -> some ChartContent {
    ForEach(allSeries) { (series: StatisticsModel.Series) in
        ForEach(series.points) { (point: StatisticsModel.Point) in
            LineMark(x: .value("Season", point.season), y: .value("Residents", point.value))
                .foregroundStyle(by: .value("Town", series.name))
        }
    }
}

@ChartContentBuilder
private func storeMarks(_ points: [StatisticsModel.Point]) -> some ChartContent {
    ForEach(points) { (point: StatisticsModel.Point) in
        AreaMark(x: .value("Season", point.season), y: .value("Units", point.value))
            .foregroundStyle(StatisticsPalette.stored.opacity(0.2))
        LineMark(x: .value("Season", point.season), y: .value("Units", point.value))
            .foregroundStyle(StatisticsPalette.stored)
    }
}

/// A dashed line at the store cap, labelled, when there is one.
@ChartContentBuilder
private func capRule(_ cap: Int) -> some ChartContent {
    ForEach([cap].filter { $0 > 0 }, id: \.self) { (value: Int) in
        RuleMark(y: .value("Store cap", value))
            .foregroundStyle(StatisticsPalette.stuck)
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
            .annotation(position: .top, alignment: .trailing) {
                Text(l10n: "stats.storeCap", value).font(.caption2).foregroundStyle(StatisticsPalette.stuck)
            }
    }
}

private struct StuckPoint: Identifiable {
    let season: Int
    let share: Double

    var id: Int {
        season
    }
}

@ChartContentBuilder
private func stuckBars(_ points: [StuckPoint]) -> some ChartContent {
    ForEach(points) { (point: StuckPoint) in
        BarMark(x: .value("Season", point.season), y: .value("Share", point.share), width: .fixed(14))
            .foregroundStyle(StatisticsPalette.stuck)
    }
}

struct StatisticsGoodDetailView: View {
    let model: StatisticsModel
    let good: Good

    var body: some View {
        let detail = model.detail(of: good)
        let seasons = detail.row.made.map(\.season)
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                GoodIconLoader.image(for: good).resizable().frame(width: 32, height: 32)
                Text(detail.row.name).font(.title2.weight(.bold))
                Spacer()
            }
            HStack(spacing: 20) {
                figure("Made", detail.row.made.last?.value ?? 0)
                figure("Used", detail.row.used.last?.value ?? 0)
                figure("Sold", detail.latestSold)
                figure("Bought", detail.latestBought)
                figure("Stored", detail.latestStored)
            }
            Text(l10n: "stats.madeUsed").font(.footnote.weight(.semibold))
            Chart {
                flowBars(detail.row.made, name: "Made")
                flowBars(detail.row.used, name: "Used")
            }
            .chartForegroundStyleScale(domain: StatisticsPalette.flowNames, range: StatisticsPalette.flowColours)
            .chartXAxis { seasonAxis(model, seasons) }
            .chartXScale(range: .plotDimension(padding: 10))
            .frame(height: 150)
            .accessibilityLabel(GameText.string("stats.a11y.madeUsed", detail.row.name))
            Text(l10n: "stats.inStore").font(.footnote.weight(.semibold))
            Chart {
                storeMarks(detail.stored)
                capRule(detail.storeCap)
            }
            .chartYScale(domain: 0 ... max(detail.storeCap, detail.stored.map(\.value).max() ?? 0, 1))
            .chartXAxis { seasonAxis(model, seasons) }
            .chartXScale(range: .plotDimension(padding: 10))
            .frame(height: 100)
            .accessibilityLabel(GameText.string("stats.a11y.inStore", detail.row.name))
            stuckStrip(detail, seasons: seasons)
            producers(detail)
        }
    }

    private func figure(_ title: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased()).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            Text(verbatim: "\(value)").font(.title3.weight(.semibold)).monospacedDigit()
        }
        .fixedSize()
    }

    @ViewBuilder
    private func stuckStrip(_ detail: StatisticsModel.GoodDetail, seasons: [Int]) -> some View {
        if detail.stuckShare.contains(where: { $0 > 0 }) {
            Text(l10n: "stats.stopped").font(.footnote.weight(.semibold)).foregroundStyle(StatisticsPalette.stuck)
            Chart { stuckBars(Array(zip(seasons, detail.stuckShare)).map(StuckPoint.init)) }
                .chartYScale(domain: 0 ... 1)
                .chartYAxis(.hidden)
                .chartXAxis { seasonAxis(model, seasons) }
                .chartXScale(range: .plotDimension(padding: 10))
                .frame(height: 50)
                .accessibilityLabel(GameText.string("stats.a11y.stopped", detail.row.name))
        }
    }

    @ViewBuilder
    private func producers(_ detail: StatisticsModel.GoodDetail) -> some View {
        if !detail.producers.isEmpty {
            Text(l10n: "stats.producers").font(.footnote.weight(.semibold))
            ForEach(detail.producers) { share in
                VStack(alignment: .leading, spacing: 4) {
                    Text(share.name)
                    GeometryReader { proxy in
                        HStack(spacing: 0) {
                            Rectangle().fill(.green).frame(width: proxy.size.width * share.working)
                            Rectangle().fill(.orange).frame(width: proxy.size.width * share.waiting)
                            Rectangle().fill(.red).frame(width: proxy.size.width * share.stuck)
                            Rectangle().fill(.gray).frame(width: proxy.size.width * share.blocked)
                        }
                        .clipShape(Capsule())
                    }
                    .frame(height: 12)
                    Text(caption(for: share))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func caption(for share: StatisticsModel.ProducerShare) -> String {
        let working = "Working \(percent(share.working))"
        let waiting = "waiting \(percent(share.waiting))"
        let stuck = "stuck \(percent(share.stuck))"
        let blocked = "blocked \(percent(share.blocked))"
        return [working, waiting, stuck, blocked].joined(separator: ", ")
    }

    private func percent(_ share: Double) -> String {
        "\(Int((share * 100).rounded())) %"
    }
}

struct StatisticsMoneyTab: View {
    let model: StatisticsModel

    var body: some View {
        let seasons: [Int] = model.balance.map(\.season)
        let allSeries: [StatisticsModel.Series] = model.income + model.spending
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(l10n: "stats.income").font(.footnote.weight(.semibold))
                Chart { moneyBars(allSeries) }
                    .chartForegroundStyleScale(domain: StatisticsPalette.moneyNames, range: StatisticsPalette.moneyColours)
                    .chartXAxis { seasonAxis(model, seasons) }
                    .chartXScale(range: .plotDimension(padding: 10))
                    .frame(height: 200)
                    .accessibilityLabel(GameText.string("stats.a11y.income"))
                Text(l10n: "stats.balance").font(.footnote.weight(.semibold))
                Chart(model.balance) { point in
                    LineMark(x: .value("Season", point.season), y: .value("Balance", point.value))
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXAxis { seasonAxis(model, seasons) }
                .chartXScale(range: .plotDimension(padding: 10))
                .frame(height: 120)
                .accessibilityLabel(GameText.string("stats.a11y.balance"))
            }
            .padding()
        }
    }
}

struct StatisticsPeopleTab: View {
    let model: StatisticsModel

    var body: some View {
        let seasons = model.balance.map(\.season)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(l10n: "stats.byTier").font(.footnote.weight(.semibold))
                Chart { tierAreas(model.tiers) }
                    .chartXAxis { seasonAxis(model, seasons) }
                    .chartXScale(range: .plotDimension(padding: 10))
                    .frame(height: 260)
                    .accessibilityLabel(GameText.string("stats.a11y.byTier"))
            }
            .padding()
        }
    }
}

struct StatisticsRivalsTab: View {
    let model: StatisticsModel

    var body: some View {
        let seasons = model.balance.map(\.season)
        let lines: [StatisticsModel.Series] = model.residentLines
        let lineColours: [Color] = model.residentLineColours.map { Color(hex: $0) }
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(l10n: "stats.byTown").font(.footnote.weight(.semibold))
                Chart { townLines(lines) }
                    .chartForegroundStyleScale(domain: lines.map(\.name), range: lineColours)
                    .chartXAxis { seasonAxis(model, seasons) }
                    .chartXScale(range: .plotDimension(padding: 10))
                    .frame(height: 220)
                    .accessibilityLabel(GameText.string("stats.a11y.byTown"))
                ForEach(model.standings) { row in
                    HStack(spacing: 10) {
                        Circle().fill(Color(hex: row.colourHex)).frame(width: 12, height: 12)
                        Text(row.name).fontWeight(row.name == "You" ? .bold : .regular)
                        Spacer()
                        Text(verbatim: "\(row.residents)").monospacedDigit()
                        Text(row.age).foregroundStyle(.secondary)
                        Text(row.wealth).monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding()
        }
    }
}
