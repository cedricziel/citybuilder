import CityCore
import SwiftUI

/// The bottom panel while the player authors a route: message, stops,
/// Undo, Cancel and Commit. Port stops open the manifest editor.
/// Spec: `platform-shells` / Route mode, Manifest editor sheet.
struct RouteAuthoringOverlay: View {
    let session: GameSession
    let authoring: RouteAuthoringViewModel
    @State private var editing: ManifestEditTarget?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("New route").font(.headline)
            Label(authoring.message, systemImage: authoring.isWarning ? "exclamationmark.triangle.fill" : "hand.tap")
                .font(.callout)
                .foregroundStyle(authoring.isWarning ? .red : .primary)
            if !authoring.inProgressWaypoints.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(authoring.inProgressWaypoints.enumerated()), id: \.offset) { index, waypoint in
                            stopChip(index: index, waypoint: waypoint)
                        }
                    }
                }
            }
            HStack {
                Button("Undo", systemImage: "arrow.uturn.backward", action: authoring.removeLastWaypoint)
                    .disabled(authoring.inProgressWaypoints.isEmpty)
                Spacer()
                Button("Cancel", role: .cancel, action: session.cancelRouteAuthoring)
                Button("Commit", action: session.commitRouteAuthoring)
                    .buttonStyle(.borderedProminent)
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .sheet(item: $editing) { target in
            ManifestEditorSheet(title: target.title, model: target.model, actions: authoring.manifest[target.id] ?? []) { actions in
                authoring.setManifest(actions, forPort: target.id)
            }
        }
    }

    @ViewBuilder
    private func stopChip(index: Int, waypoint: Waypoint) -> some View {
        let snapshot = authoring.snapshot
        let label = snapshot.map { RouteStopLabel.text(for: waypoint, in: $0) } ?? "Stop"
        if case let .port(id) = waypoint, let snapshot {
            Button {
                editing = ManifestEditTarget(id: id, title: label, model: ManifestEditorModel(snapshot: snapshot, port: id))
            } label: {
                let actions = authoring.manifest[id]?.count ?? 0
                Label("\(index + 1). \(label)\(actions > 0 ? " · \(actions)" : "")", systemImage: "shippingbox")
            }
            .buttonStyle(.bordered)
            .accessibilityHint("Edit what ships do here")
        } else {
            Text("\(index + 1). \(label)")
                .font(.callout)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.quaternary, in: Capsule())
        }
    }
}
