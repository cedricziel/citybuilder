import CityCore
import SwiftUI

/// The armed caption and inspector, shown whenever route mode is off. Split out of `CityRootView` to keep the
/// main file under SwiftLint's 500-line ceiling.
extension CityRootView {
    @ViewBuilder
    var buildControls: some View {
        if session.selectedTool != .inspect {
            Text(armedCaption)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.thinMaterial, in: Capsule())
        }
        Spacer()
        let inspector = session.inspector
        if session.selectedTool == .inspect, !inspector.bullets.isEmpty {
            HStack {
                InspectorView(
                    viewModel: inspector,
                    onCommission: session.commissionArt,
                    onPickExport: session.pickExport,
                    onStartRoute: { session.beginRouteAuthoring(from: $0) }
                )
                inspectorActionsButton
                Spacer()
            }
        }
    }

    /// Caption under the build palette while a tool is armed.
    private var armedCaption: String {
        let name = session.selectedTool.displayName
        let cost = session.armedToolCost
        if cost > 0 {
            return "Tap or drag to place \(name.lowercased()) — $\(cost)"
        }
        if session.selectedTool == .demolish {
            return "Tap or drag to demolish"
        }
        return "Tap a tile to \(name.lowercased())"
    }
}
