import CityCore
import SwiftUI

/// Per-tick performance overlay. Reads World.TickMetrics from the most
/// recent tick and shows wall-clock duration. Hidden unless the session
/// flips `showsPerfOverlay`. Per spec rendering-2_5d M11 instrumentation
/// task 11.1.
public struct PerfOverlayView: View {
    public let lastTickNanos: UInt64?
    public let tickCount: UInt64

    public init(lastTickNanos: UInt64?, tickCount: UInt64) {
        self.lastTickNanos = lastTickNanos
        self.tickCount = tickCount
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("tick \(tickCount)").font(.caption2.monospaced())
            if let nanos = lastTickNanos {
                let ms = Double(nanos) / 1_000_000
                Text(String(format: "%.2f ms/tick", ms))
                    .font(.caption2.monospaced())
                    .foregroundStyle(ms < 5.0 ? .green : .red)
            }
        }
        .padding(6)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
    }
}
