import CityCore
import SwiftUI

/// HUD frame shown at the top of the screen. Idiom-adaptive (compact vs.
/// regular) per spec platform-shells.
public struct HUDFrameView: View {
    public let viewModel: HUDViewModel
    private let labels = LayoutDecisions.decisions(for: .compact).labels

    public init(viewModel: HUDViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !viewModel.dateText.isEmpty {
                Label(viewModel.dateText, systemImage: "calendar")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Date: \(viewModel.dateText)")
            }
            HStack(spacing: 16) {
                badge(label: "Money", value: viewModel.formattedMoney)
                badge(label: "Population", value: viewModel.formattedPopulation)
                if let name = viewModel.currentIslandName {
                    badge(label: "Island", value: name)
                }
                Spacer()
            }
            if viewModel.currentIsland != nil {
                stocksRow
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var stocksRow: some View {
        let chips = viewModel.stocksRow
        if !chips.isEmpty {
            // Scrolls so a long goods list never squeezes the counts or
            // widens the HUD past the screen.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(chips, id: \.good) { chip in
                        chipView(chip)
                            .fixedSize()
                    }
                }
            }
            .accessibilityLabel("Island stocks")
        }
    }

    private func chipView(_ chip: HUDGoodChip) -> some View {
        HStack(spacing: 4) {
            GoodIconLoader.image(for: chip.good)
                .resizable()
                .interpolation(GoodIconLoader.pixelArtInterpolation)
                .frame(width: 16, height: 16)
            Text("\(chip.count)")
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.semibold)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(chip.good.rawValue.capitalized) \(chip.count)")
    }

    private func badge(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(labels.statCaptionLineLimit)
                .minimumScaleFactor(labels.minimumScaleFactor)
            Text(value)
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.semibold)
                .lineLimit(labels.statValueLineLimit)
                .minimumScaleFactor(labels.minimumScaleFactor)
        }
    }
}
