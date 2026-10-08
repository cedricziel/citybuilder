import CityCore
import SwiftUI

/// Tool palette. Tapping a button ARMS the corresponding tool — the
/// player then taps a world tile to actually place the building / road
/// (or demolish). Tapping the armed tool's button again disarms back
/// to inspect mode.
public struct BuildPaletteView: View {
    public let armed: BuildTool
    public let selectTool: (BuildTool) -> Void

    public init(armed: BuildTool, selectTool: @escaping (BuildTool) -> Void) {
        self.armed = armed
        self.selectTool = selectTool
    }

    private let labels = LayoutDecisions.decisions(for: .compact).labels

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(BuildingKind.allCases, id: \.self) { kind in
                    paletteButton(tool: .place(kind))
                }
                Divider().frame(height: 20)
                paletteButton(tool: .demolish)
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func paletteButton(tool: BuildTool) -> some View {
        let isArmed = armed == tool
        return Button {
            selectTool(tool)
        } label: {
            Text(tool.displayName)
                .font(.caption.monospaced())
                .lineLimit(labels.paletteLabelLineLimit)
                .fixedSize()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isArmed ? Color.accentColor.opacity(0.85) : Color.clear)
                .foregroundStyle(isArmed ? Color.white : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.borderless)
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(isArmed ? Color.accentColor : Color.secondary.opacity(0.4), lineWidth: 1)
        )
    }
}
