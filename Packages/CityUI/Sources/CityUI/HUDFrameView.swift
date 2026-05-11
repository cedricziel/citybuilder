import SwiftUI

/// HUD frame shown at the top of the screen. Idiom-adaptive (compact vs.
/// regular) per spec platform-shells.
public struct HUDFrameView: View {
    public let viewModel: HUDViewModel

    public init(viewModel: HUDViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        HStack(spacing: 24) {
            badge(label: "Money", value: viewModel.formattedMoney)
            badge(label: "Population", value: viewModel.formattedPopulation)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func badge(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.semibold)
        }
    }
}
