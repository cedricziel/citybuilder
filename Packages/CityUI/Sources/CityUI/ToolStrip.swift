import CityCore
import Foundation
import SwiftUI

/// Text on the tool strip. Spec: `platform-shells` / Tool strip.
public enum ToolStripText {
    public static func hint(for tool: BuildTool, touch: Bool) -> String {
        switch tool {
        case .inspect: ""
        case .demolish: touch ? "Tap a building to demolish" : "Click a building to demolish"
        case .place: touch ? "Tap or drag to place" : "Click or drag to place"
        }
    }

    public static var isTouch: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }
}

/// Spec: `platform-shells` / Tool strip.
public extension GameSession {
    /// The tool strip's material chips: the hovered tile's when there is
    /// one, otherwise the camera-center tile's, so touch players see them
    /// before the first tap. Nil when the armed tool needs no materials.
    var armedCostBreakdown: [Good: GhostCost]? {
        if let ghost = ghostState() { return ghost.costBreakdown }
        guard case let .place(kind) = selectedTool else { return nil }
        return costBreakdown(for: kind, anchor: world.camera.centerTile())
    }
}

/// The armed tool's sprite, name, cost, hint, material chips and cancel.
struct ToolStripView: View {
    let session: GameSession

    var body: some View {
        let tool = session.selectedTool
        if tool != .inspect {
            HStack(spacing: 10) {
                art(tool)
                VStack(alignment: .leading, spacing: 0) {
                    title(tool)
                    Text(ToolStripText.hint(for: tool, touch: ToolStripText.isTouch))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                if let breakdown = session.armedCostBreakdown, !breakdown.isEmpty {
                    Divider().frame(height: 28)
                    ForEach(Good.allCases.filter { breakdown[$0] != nil }, id: \.self) { good in
                        if let cost = breakdown[good] {
                            GoodChipView(good: good, text: "\(cost.have)/\(cost.need)", color: Self.color(for: cost.status))
                                .accessibilityLabel(Self.label(for: good, cost: cost))
                        }
                    }
                }
                Button(action: session.clearTool) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel tool")
            }
            .padding(.leading, 10)
            .padding([.trailing, .vertical], 6)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: HUDMetrics.cornerRadius, style: .continuous))
        }
    }

    @ViewBuilder
    private func art(_ tool: BuildTool) -> some View {
        if case let .place(kind) = tool {
            BuildingIconLoader.image(for: kind)
                .resizable()
                .interpolation(GoodIconLoader.pixelArtInterpolation)
                .scaledToFit()
                .frame(width: 32, height: 28)
        } else {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.red)
                .frame(width: 32, height: 28)
        }
    }

    private func title(_ tool: BuildTool) -> some View {
        HStack(spacing: 0) {
            Text(tool.displayName).font(.subheadline.weight(.semibold))
            if session.armedToolCost > 0 {
                Text(" · $\(session.armedToolCost)")
                    .font(.system(.subheadline, design: .monospaced).weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    static func color(for status: CostStatus) -> Color {
        switch status {
        case .ok: .primary
        case .queueable: .orange
        case .blocked: .red
        }
    }

    static func label(for good: Good, cost: GhostCost) -> String {
        let base = "\(good.rawValue) \(cost.have) of \(cost.need)"
        return switch cost.status {
        case .ok: base
        case .queueable: "\(base), queue OK"
        case .blocked: "\(base), blocked"
        }
    }
}
