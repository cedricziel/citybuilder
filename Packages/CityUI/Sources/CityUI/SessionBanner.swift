import CityCore
import SwiftUI

/// A short-lived announcement: a history event or a new age.
public struct SessionBanner: Equatable, Sendable {
    public let title: String
    public let description: String
}

extension GameSession {
    static let bannerTicks: UInt64 = 60

    /// The banner showing now, if any. Spec: `platform-shells` / History
    /// events show a banner, Age changes show a banner.
    public var banner: SessionBanner? {
        guard let state = bannerState, world.tickCount < state.hidesAtTick else { return nil }
        return state.banner
    }

    func noteBannerEvents(in events: [WorldEvent]) {
        for event in events {
            switch event {
            case let .historyEvent(history):
                show(SessionBanner(title: history.title, description: history.description))
            case let .ageAdvanced(age):
                show(SessionBanner(title: "The \(age.displayName) age begins", description: age.blurb))
            default:
                continue
            }
        }
    }

    private func show(_ banner: SessionBanner) {
        bannerState = (banner, world.tickCount + Self.bannerTicks)
    }
}

/// Parchment-coloured card announcing a history event or a new age.
struct SessionBannerView: View {
    let banner: SessionBanner?

    var body: some View {
        if let banner {
            VStack(spacing: 2) {
                Text(banner.title)
                    .font(.headline)
                Text(banner.description)
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
