import CityCore
import Foundation
import SwiftUI

/// Text on the tool strip. Spec: `platform-shells` / Tool strip.
public enum ToolStripText {
    /// `paintingRoad` only matters on Apple TV, where select toggles road
    /// painting. `inReach` is the armed hut's trees or forester's open
    /// grass at its candidate site (`GameSession.armedInReachCount`).
    public static func hint(for tool: BuildTool, idiom: HUDIdiom, paintingRoad: Bool = false, inReach: Int? = nil) -> String {
        let name = tool.displayName.lowercased()
        let touch = idiom.isTouch
        let base = switch (tool, idiom) {
        case (.inspect, _): ""
        case (.demolish, _): touch ? "Tap a building to demolish" : "Click a building to demolish"
        case (.place(.road), .tv): paintingRoad ? "Click to stop painting road" : "Click to start painting road"
        case (.place, .tv): "Move, then click to place \(name). Back to cancel."
        case (.place, _): "\(touch ? "Tap" : "Click") or drag to place \(name)"
        }
        guard case let .place(kind) = tool, let noun = inReachNoun(kind), let inReach else { return base }
        let count = "\(inReach) \(noun) in reach"
        // The Apple TV instruction ends in a sentence, so the count leads.
        return idiom == .tv ? "\(count) · \(base)" : "\(base) · \(count)"
    }

    /// What a building of `kind` counts in its catchment, nil when it
    /// counts nothing.
    static func inReachNoun(_ kind: BuildingKind) -> String? {
        switch kind {
        case .lumberjackHut: "trees"
        case .forester: "open grass"
        default: nil
        }
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

    /// Whether the player may place `kind` at `tile` and can pay for it,
    /// the ghost's green tint.
    internal func isValidPlacement(_ kind: BuildingKind, at tile: TileCoordinate) -> Bool {
        guard case .allowed = world.canPlace(kind, at: tile) else { return false }
        return world.economy.balance >= BuildingCatalog.spec(for: kind).cost
    }

    /// Trees or open grass the armed hut or forester would reach at its
    /// candidate site: the pending placement, else the hovered tile, else
    /// on touch the camera-center tile, as for the material chips. Nil for
    /// other tools, without a candidate site, or where the building can't
    /// go (`add-forestry` D5).
    func armedInReachCount(idiom: HUDIdiom) -> Int? {
        let fallback = idiom.isTouch ? world.camera.centerTile() : nil
        let kind: BuildingKind
        let anchor: TileCoordinate
        if let pending = pendingPlacement {
            (kind, anchor) = (pending.kind, pending.anchor)
        } else if case let .place(armed) = selectedTool, let tile = hoveredTile ?? fallback {
            (kind, anchor) = (armed, tile)
        } else {
            return nil
        }
        guard ToolStripText.inReachNoun(kind) != nil, isValidPlacement(kind, at: anchor) else { return nil }
        return world.catchmentCount(kind: kind, anchor: anchor, owner: .player)
    }
}

/// The armed tool's sprite, name, cost, hint, material chips and cancel.
struct ToolStripView: View {
    let session: GameSession
    let idiom: HUDIdiom

    var body: some View {
        let tool = session.selectedTool
        if tool != .inspect {
            HStack(spacing: 10) {
                art(tool)
                VStack(alignment: .leading, spacing: 0) {
                    title(tool)
                    Text(ToolStripText.hint(for: tool, idiom: idiom, inReach: session.armedInReachCount(idiom: idiom)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                if let breakdown = session.armedCostBreakdown, !breakdown.isEmpty {
                    Divider().frame(height: 28)
                    ForEach(Good.allCases.filter { breakdown[$0] != nil }, id: \.self) { good in
                        if let cost = breakdown[good] {
                            GoodChipView(
                                good: good,
                                text: "\(cost.have)/\(cost.need)",
                                color: Self.color(for: cost.status),
                                help: Self.label(for: good, cost: cost)
                            )
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
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: HUDMetrics.cornerRadius, style: .continuous))
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
        let base = "\(GoodsCatalog.spec(for: good).displayName): \(cost.have) in store, \(cost.need) needed"
        return switch cost.status {
        case .ok: base
        case .queueable: "\(base). It waits for the rest"
        case .blocked: "\(base). Not enough"
        }
    }
}
