import Charts
import CityCore
import SwiftUI

private enum StatisticsPalette {
    static let made = Color.blue
    static let used = Color.orange
    static let stuck = Color.red
    static let stored = Color.gray
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
            Text("Made and used per season").font(.footnote.weight(.semibold))
            Chart {
                ForEach(detail.row.made) { point in
                    BarMark(x: .value("Season", point.season), y: .value("Units", point.value), width: .fixed(7))
                        .position(by: .value("Flow", "Made"))
                        .foregroundStyle(by: .value("Flow", "Made"))
                }
                ForEach(detail.row.used) { point in
                    BarMark(x: .value("Season", point.season), y: .value("Units", point.value), width: .fixed(7))
                        .position(by: .value("Flow", "Used"))
                        .foregroundStyle(by: .value("Flow", "Used"))
                }
            }
            .chartForegroundStyleScale(["Made": StatisticsPalette.made, "Used": StatisticsPalette.used])
            .chartXAxis { seasonAxis(model, seasons) }
            .chartXScale(range: .plotDimension(padding: 10))
            .frame(height: 150)
            .accessibilityLabel("\(detail.row.name) made and used per season")
            Text("In store at season end").font(.footnote.weight(.semibold))
            Chart(detail.stored) { point in
                AreaMark(x: .value("Season", point.season), y: .value("Units", point.value))
                    .foregroundStyle(StatisticsPalette.stored.opacity(0.2))
                LineMark(x: .value("Season", point.season), y: .value("Units", point.value))
                    .foregroundStyle(StatisticsPalette.stored)
            }
            .chartXAxis { seasonAxis(model, seasons) }
            .chartXScale(range: .plotDimension(padding: 10))
            .frame(height: 100)
            .accessibilityLabel("\(detail.row.name) in store at season end")
            stuckStrip(detail, seasons: seasons)
            producers(detail)
        }
    }

    private func figure(_ title: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased()).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            Text("\(value)").font(.title3.weight(.semibold)).monospacedDigit()
        }
        .fixedSize()
    }

    @ViewBuilder
    private func stuckStrip(_ detail: StatisticsModel.GoodDetail, seasons: [Int]) -> some View {
        if detail.stuckShare.contains(where: { $0 > 0 }) {
            Text("Stopped: output stuck").font(.footnote.weight(.semibold)).foregroundStyle(StatisticsPalette.stuck)
            Chart(Array(zip(seasons, detail.stuckShare)), id: \.0) { season, share in
                BarMark(x: .value("Season", season), y: .value("Share", share), width: .fixed(14))
                    .foregroundStyle(StatisticsPalette.stuck)
            }
            .chartYScale(domain: 0 ... 1)
            .chartYAxis(.hidden)
            .chartXAxis { seasonAxis(model, seasons) }
            .chartXScale(range: .plotDimension(padding: 10))
            .frame(height: 50)
            .accessibilityLabel("Share of each season the \(detail.row.name) producers were stopped, output stuck")
        }
    }

    @ViewBuilder
    private func producers(_ detail: StatisticsModel.GoodDetail) -> some View {
        if !detail.producers.isEmpty {
            Text("Who makes it, last season").font(.footnote.weight(.semibold))
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
                    Text(
                        "Working \(percent(share.working)), waiting \(percent(share.waiting)), "
                            + "stuck \(percent(share.stuck)), blocked \(percent(share.blocked))"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func percent(_ share: Double) -> String {
        "\(Int((share * 100).rounded())) %"
    }
}

struct StatisticsMoneyTab: View {
    let model: StatisticsModel

    var body: some View {
        let seasons = model.balance.map(\.season)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Income and upkeep per season").font(.footnote.weight(.semibold))
                Chart {
                    ForEach(model.income + model.spending) { series in
                        ForEach(series.points) { point in
                            BarMark(x: .value("Season", point.season), y: .value("Money", point.value), width: .fixed(14))
                                .foregroundStyle(by: .value("Kind", series.name))
                        }
                    }
                }
                .chartForegroundStyleScale([
                    "Tax": Color.green, "Trade": Color.blue, "Upkeep": Color.orange, "Bought": Color.purple
                ])
                .chartXAxis { seasonAxis(model, seasons) }
                .chartXScale(range: .plotDimension(padding: 10))
                .frame(height: 200)
                .accessibilityLabel("Tax and trade income above zero, upkeep and purchases below, per season")
                Text("Balance at season end").font(.footnote.weight(.semibold))
                Chart(model.balance) { point in
                    LineMark(x: .value("Season", point.season), y: .value("Balance", point.value))
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXAxis { seasonAxis(model, seasons) }
                .chartXScale(range: .plotDimension(padding: 10))
                .frame(height: 120)
                .accessibilityLabel("Balance at the end of each season")
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
                Text("Residents by tier, season end").font(.footnote.weight(.semibold))
                Chart {
                    ForEach(model.tiers) { series in
                        ForEach(series.points) { point in
                            AreaMark(x: .value("Season", point.season), y: .value("Residents", point.value))
                                .foregroundStyle(by: .value("Tier", series.name))
                        }
                    }
                }
                .chartXAxis { seasonAxis(model, seasons) }
                .chartXScale(range: .plotDimension(padding: 10))
                .frame(height: 260)
                .accessibilityLabel("Residents by house tier at the end of each season")
            }
            .padding()
        }
    }
}

struct StatisticsRivalsTab: View {
    let model: StatisticsModel

    var body: some View {
        let seasons = model.balance.map(\.season)
        let lines = model.residentLines
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Residents by town, season end").font(.footnote.weight(.semibold))
                Chart {
                    ForEach(lines) { series in
                        ForEach(series.points) { point in
                            LineMark(x: .value("Season", point.season), y: .value("Residents", point.value))
                                .foregroundStyle(by: .value("Town", series.name))
                        }
                    }
                }
                .chartForegroundStyleScale(
                    domain: lines.map(\.name), range: model.residentLineColours.map { Color(hex: $0) }
                )
                .chartXAxis { seasonAxis(model, seasons) }
                .chartXScale(range: .plotDimension(padding: 10))
                .frame(height: 220)
                .accessibilityLabel("Residents of your town and each rival at the end of each season")
                ForEach(model.standings) { row in
                    HStack(spacing: 10) {
                        Circle().fill(Color(hex: row.colourHex)).frame(width: 12, height: 12)
                        Text(row.name).fontWeight(row.name == "You" ? .bold : .regular)
                        Spacer()
                        Text("\(row.residents)").monospacedDigit()
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
