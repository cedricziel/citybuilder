import SwiftUI

/// The first-hour guide under the top-right HUD buttons: a card with the
/// ledger and the five steps, or on a compact width a one-line capsule
/// that expands on tap. Spec: `platform-shells` / First-hour guide.
struct FirstStepsCardView: View {
    let guide: FirstStepsGuide
    let layout: HUDLayout
    let onHide: () -> Void
    @State private var isExpanded = false

    static let width: CGFloat = 300

    var body: some View {
        if layout.isCompactWidth, !isExpanded {
            Button { isExpanded = true } label: {
                HStack(spacing: 6) {
                    Text("First steps \(guide.metCount)/\(guide.steps.count)").font(.caption.weight(.semibold))
                    Text("· net \(FirstStepsLedger.money(guide.ledger.net))")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(guide.ledger.isNegative ? .red : .secondary)
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 32)
                .background(.thinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows the first steps")
        } else {
            card
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("First steps").font(.headline)
                Text("\(guide.metCount)/\(guide.steps.count)")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button(action: onHide) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Hide first steps")
            }
            ledger
            Text("Per collection, every 50 ticks.")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(guide.steps, id: \.title) { step in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: step.isMet ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(step.isMet ? .green : .secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(step.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(step.isMet ? .secondary : .primary)
                        Text(step.reason).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityValue(step.isMet ? "Done" : "Open")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: Self.width, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: HUDMetrics.cornerRadius, style: .continuous))
        .onTapGesture { if layout.isCompactWidth { isExpanded = false } }
    }

    private var ledger: some View {
        HStack(spacing: 6) {
            figure("TAX", guide.ledger.tax)
            figure("UPKEEP", guide.ledger.upkeep)
            figure("NET", guide.ledger.net, color: guide.ledger.isNegative ? .red : .primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func figure(_ label: String, _ amount: Int64, color: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(FirstStepsLedger.money(amount)).font(.system(.callout, design: .monospaced)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
