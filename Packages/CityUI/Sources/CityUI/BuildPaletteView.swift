import CityCore
import SwiftUI

/// Minimal M2 build palette: one button per BuildingKind. M3 turns this
/// into a full categorized palette with cost previews and a placement
/// preview overlay.
public struct BuildPaletteView: View {
    public let placeAction: (BuildingKind) -> Void

    public init(placeAction: @escaping (BuildingKind) -> Void) {
        self.placeAction = placeAction
    }

    public var body: some View {
        HStack(spacing: 8) {
            ForEach(BuildingKind.allCases, id: \.self) { kind in
                Button {
                    placeAction(kind)
                } label: {
                    Text(label(for: kind))
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func label(for kind: BuildingKind) -> String {
        switch kind {
        case .house: "House"
        case .warehouse: "Warehouse"
        case .road: "Road"
        case .lumberjackHut: "Lumberjack"
        case .sawmill: "Sawmill"
        case .townCenter: "Town Ctr."
        }
    }
}
