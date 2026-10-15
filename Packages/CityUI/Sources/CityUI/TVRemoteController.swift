import CityCore
import Foundation
import Observation

/// Owns the remote input mapper and the controller adapter for one game.
/// The tvOS host feeds it presses and controller snapshots and applies the
/// focus changes it reports; the HUD reads the tooltip from it. Kept
/// platform-neutral so the wiring's rules run on the Mac. Design D3, D4.
@MainActor
@Observable
public final class TVRemoteController {
    public let session: GameSession
    public private(set) var mapper = RemoteInputMapper()
    public private(set) var tooltipBuilding: EntityID?
    @ObservationIgnored private var adapter = GameControllerAdapter()
    /// The host's handler for focus changes.
    @ObservationIgnored public var applyEffect: ((RemoteEffect) -> Void)?

    public init(session: GameSession) {
        self.session = session
    }

    public func send(_ input: RemoteInput, at time: TimeInterval) {
        apply(mapper.handle(input, at: time, session: session), at: time)
    }

    /// A press from UIKit; dropped when GameController already sent it.
    public func sendUIKit(_ input: RemoteInput, at time: TimeInterval) {
        if let input = adapter.uiKitPress(input, at: time) {
            send(input, at: time)
        }
    }

    public func send(_ snapshot: ControllerSnapshot, at time: TimeInterval) {
        for input in adapter.update(snapshot, at: time) {
            send(input, at: time)
        }
    }

    public func send(_ snapshot: RemoteSnapshot, at time: TimeInterval) {
        for input in adapter.update(snapshot, at: time) {
            send(input, at: time)
        }
    }

    /// The focus engine moved focus onto or off the map, for example when
    /// a sheet opened or closed. Keeps the mapper's owner in step.
    public func focusMoved(toMap onMap: Bool, at time: TimeInterval) {
        let owner: RemoteFocus = onMap ? .map : .hud
        if mapper.focus != owner {
            send(.focusChanged(owner), at: time)
        }
    }

    /// The HUD armed a tool. A building starts its placement at the
    /// reticle and focus returns to the map, as the road and demolish do.
    /// Changes made from the map, such as Back putting a tool away, move
    /// no focus.
    public func toolChanged(to tool: BuildTool, at time: TimeInterval) {
        guard mapper.focus == .hud else { return }
        switch tool {
        case .inspect:
            return
        case let .place(kind):
            apply(mapper.chooseBuilding(kind, at: time, session: session), at: time)
        case .demolish:
            send(.focusChanged(.map), at: time)
            applyEffect?(.focusMap)
        }
    }

    private func apply(_ effects: [RemoteEffect], at time: TimeInterval) {
        for effect in effects {
            applyEffect?(effect)
        }
        let tooltip = mapper.tooltipBuilding(at: time, session: session)
        if tooltip != tooltipBuilding {
            tooltipBuilding = tooltip
        }
    }
}
