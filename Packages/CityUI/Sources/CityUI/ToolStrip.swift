import CityCore
import Foundation
import SwiftUI

/// Text on the tool strip. Spec: `platform-shells` / Tool strip.
public enum ToolStripText {
    /// `paintingRoad` only matters on Apple TV, where select toggles road
    /// painting. `inReach` is the armed hut's trees or forester's open
    /// grass at its candidate site (`GameSession.armedInReachCount`).
    /// `warning` is the first-hour guide's (`GameSession.armedGuideWarning`).
    public static func hint(
        for tool: BuildTool, idiom: HUDIdiom, paintingRoad: Bool = false, inReach: Int? = nil, warning: String? = nil
    ) -> String {
        let hint = baseHint(for: tool, idiom: idiom, paintingRoad: paintingRoad, inReach: inReach)
        guard let warning else { return hint }
        return "\(hint) · \(warning)"
    }

    private static func baseHint(for tool: BuildTool, idiom: HUDIdiom, paintingRoad: Bool, inReach: Int?) -> String {
        let name = GameText.inSentence(tool.displayName)
        // The Apple TV remote's touch surface clicks, so its hints say so.
        let touch = idiom == .phone || idiom == .pad
        let base = switch (tool, idiom) {
        case (.inspect, _): ""
        case (.demolish, _): if touch { GameText.string("tool.demolishHint.tap") } else { GameText.string("tool.demolishHint.click") }
        case (.place(.road), .tv): if paintingRoad { GameText.string("tool.roadStop") } else { GameText.string("tool.roadStart") }
        case (.place, .tv): GameText.string("tool.placeTV", name)
        // Touch positions a building first: a tap shows the nudge arrows, and the check places it.
        case (.place(.road), .phone), (.place(.road), .pad): GameText.string("tool.dragPlace.tap", name)
        case (.place, .phone), (.place, .pad): GameText.string("tool.positionPlace")
        case (.place, _): GameText.string("tool.dragPlace.click", name)
        }
        guard case let .place(kind) = tool, let inReach, let count = inReachText(kind, count: inReach) else { return base }
        // The Apple TV instruction ends in a sentence, so the count leads.
        return idiom == .tv ? "\(count) · \(base)" : "\(base) · \(count)"
    }

    /// "18 trees in reach" for a hut's site, "12 open grass in reach" for a forester's.
    /// The hut's key has no singular, unlike `aoe.trees`, because the strip has always said "1 trees".
    static func inReachText(_ kind: BuildingKind, count: Int) -> String? {
        switch kind {
        case .lumberjackHut: GameText.string("tool.inReach.trees", count)
        case .forester: GameText.string("aoe.grass", count)
        default: nil
        }
    }
}

/// Spec: `platform-shells` / Tool strip.
public extension GameSession {
    /// Cost of the currently-armed building (0 if no place tool armed).
    var armedToolCost: Int64 {
        if case let .place(kind) = selectedTool {
            return BuildingCatalog.spec(for: kind).cost
        }
        return 0
    }

    /// The tool strip's material chips: the hovered tile's when there is
    /// one, otherwise the camera-center tile's, so touch players see them
    /// before the first tap. Nil when the armed tool needs no materials.
    var armedCostBreakdown: [Good: GhostCost]? {
        if let ghost = ghostState() { return ghost.costBreakdown }
        guard case let .place(kind) = selectedTool else { return nil }
        return costBreakdown(for: kind, anchor: world.camera.centerTile())
    }

    /// Trees or open grass the armed hut or forester would reach at its
    /// candidate site: the pending placement, else the hovered tile, else
    /// on touch the camera-center tile, as for the material chips. Nil for
    /// other tools, without a candidate site, or where the building can't
    /// go (`add-forestry` D5).
    func armedInReachCount(idiom: HUDIdiom) -> Int? {
        guard let (kind, anchor) = armedCandidateSite(idiom: idiom),
              ToolStripText.inReachText(kind, count: 0) != nil, isValidPlacement(kind, at: anchor)
        else { return nil }
        return world.catchmentCount(kind: kind, anchor: anchor, owner: .player)
    }

    /// The building and site the tool strip describes: the pending
    /// placement, else the armed building at the hovered tile, else on
    /// touch at the camera-center tile.
    internal func armedCandidateSite(idiom: HUDIdiom) -> (kind: BuildingKind, anchor: TileCoordinate)? {
        if let pending = pendingPlacement { return (pending.kind, pending.anchor) }
        let fallback = idiom.isTouch ? world.camera.centerTile() : nil
        guard case let .place(armed) = selectedTool, let tile = hoveredTile ?? fallback else { return nil }
        return (armed, tile)
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
                    Text(ToolStripText.hint(
                        for: tool, idiom: idiom, paintingRoad: session.isPaintingRoad,
                        inReach: session.armedInReachCount(idiom: idiom), warning: session.armedGuideWarning(idiom: idiom)
                    ))
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
                .accessibilityLabel(GameText.string("tools.cancel"))
            }
            .padding(.leading, 10)
            .padding([.trailing, .vertical], 6)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: HUDMetrics.cornerRadius, style: .continuous))
            .hudChromeTypeSize()
        }
    }

    @ViewBuilder
    private func art(_ tool: BuildTool) -> some View {
        if case let .place(kind) = tool {
            BuildingIconLoader.image(for: kind)
                .resizable()
                .interpolation(BuildingIconLoader.interpolation(for: kind))
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
                Text(verbatim: " · $\(session.armedToolCost)")
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
        let base = GameText.string("tool.cost", good.displayName, cost.have, cost.need)
        return switch cost.status {
        case .ok: base
        case .queueable: GameText.string("tool.cost.waits", base)
        case .blocked: GameText.string("tool.cost.blocked", base)
        }
    }
}
