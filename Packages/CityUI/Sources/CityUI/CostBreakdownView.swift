import CityCore
import SwiftUI

/// One chip per required good when a build tool is armed. The view
/// renders `need / have` per good, painting the chip text red when
/// `have < need` so the player sees the shortfall before placing.
/// Hidden entirely when the ghost preview has no material cost (road,
/// town center, demolish, inspect).
public struct CostBreakdownView: View {
    public let breakdown: [Good: GhostCost]

    public init(breakdown: [Good: GhostCost]) {
        self.breakdown = breakdown
    }

    public var body: some View {
        if !breakdown.isEmpty {
            HStack(spacing: 8) {
                ForEach(Good.allCases, id: \.self) { good in
                    if let cost = breakdown[good] {
                        chip(for: good, cost: cost)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityLabel("Materials needed")
        }
    }

    private func chip(
        for good: Good,
        cost: GhostCost
    ) -> some View {
        HStack(spacing: 4) {
            GoodIconLoader.image(for: good)
                .resizable()
                .interpolation(GoodIconLoader.pixelArtInterpolation)
                .frame(width: 14, height: 14)
            Text("\(cost.have)/\(cost.need)")
                .font(.system(.caption2, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundStyle(color(for: cost.status))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label(for: good, cost: cost))
    }

    private func color(for status: CostStatus) -> Color {
        switch status {
        case .ok: return .primary
        case .queueable: return .orange
        case .blocked: return .red
        }
    }

    private func label(for good: Good, cost: GhostCost) -> String {
        let base = "\(good.rawValue) \(cost.have) of \(cost.need)"
        switch cost.status {
        case .ok: return base
        case .queueable: return "\(base), queue OK"
        case .blocked: return "\(base), blocked"
        }
    }
}
