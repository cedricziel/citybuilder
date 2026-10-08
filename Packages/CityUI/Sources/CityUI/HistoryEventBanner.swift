import CityCore
import SwiftUI

extension GameSession {
    static let historyBannerTicks: UInt64 = 60

    /// The history event whose banner is showing, if any.
    public var historyBanner: HistoryEvent? {
        guard let state = historyBannerState, world.tickCount < state.hidesAtTick else { return nil }
        return state.event
    }

    func noteHistoryEvents(in events: [WorldEvent]) {
        for case let .historyEvent(event) in events {
            historyBannerState = (event, world.tickCount + Self.historyBannerTicks)
        }
    }
}

/// Parchment-coloured card naming a history event that just fired.
/// Spec: `platform-shells` / History events show a banner.
struct HistoryEventBanner: View {
    let event: HistoryEvent?

    var body: some View {
        if let event {
            VStack(spacing: 2) {
                Text(event.title)
                    .font(.headline)
                Text(event.description)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(Color(red: 0.24, green: 0.16, blue: 0.08))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(red: 0.93, green: 0.86, blue: 0.70), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(red: 0.42, green: 0.29, blue: 0.16), lineWidth: 2))
            .padding(.horizontal, 24)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .combine)
        }
    }
}
