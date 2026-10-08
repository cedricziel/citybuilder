import SwiftUI

/// Red capsule naming why the last placement was rejected. Polls the
/// HUD's expiry so the message disappears on its own. Spec:
/// `platform-shells` / Placement rejection feedback.
struct PlacementRejectionBanner: View {
    let hud: HUDViewModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            if let message = hud.rejectionMessage(at: context.date) {
                Text(message)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.red.opacity(0.85), in: Capsule())
                    .accessibilityLabel("Can't place: \(message)")
            }
        }
    }
}
