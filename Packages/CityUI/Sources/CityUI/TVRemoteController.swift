import CityCore
import Foundation
import Observation

/// Owns the remote input mapper and the controller adapters for one game.
/// The tvOS host feeds it presses and controller snapshots and applies the
/// focus changes it reports; the HUD and the reticle read `focus` and the
/// tooltip from it. Kept platform-neutral so the wiring's rules run on the
/// Mac. Design D3, D4.
@MainActor
@Observable
public final class TVRemoteController {
    public let session: GameSession
    /// Who owns the remote. Published only when it changes, so the HUD
    /// and the reticle do not redraw on every frame's tick.
    public private(set) var focus: RemoteFocus = .map
    public private(set) var tooltipBuilding: EntityID?
    /// True from a select on the selected building until the inspector
    /// callout holds focus; the rest of the HUD steps aside meanwhile.
    public private(set) var focusesInspector = false
    @ObservationIgnored public private(set) var mapper = RemoteInputMapper()
    /// One adapter per controller, so each keeps its own button state.
    @ObservationIgnored private var adapters: [Int: GameControllerAdapter] = [:]
    /// The host's handler for focus changes.
    @ObservationIgnored public var applyEffect: ((RemoteEffect) -> Void)?

    public init(session: GameSession) {
        self.session = session
    }

    public func send(_ input: RemoteInput, at time: TimeInterval) {
        apply(mapper.handle(input, at: time, session: session), at: time)
    }

    /// A press from UIKit; dropped when a controller already sent it.
    public func sendUIKit(_ input: RemoteInput, at time: TimeInterval) {
        guard adapters.values.allSatisfy({ $0.uiKitPress(input, at: time) != nil }) else { return }
        send(input, at: time)
    }

    public func send(_ snapshot: ControllerSnapshot, from controller: Int, at time: TimeInterval) {
        forward(adapters[controller, default: GameControllerAdapter()].update(snapshot, at: time), at: time)
    }

    public func send(_ snapshot: RemoteSnapshot, from controller: Int, at time: TimeInterval) {
        forward(adapters[controller, default: GameControllerAdapter()].update(snapshot, at: time), at: time)
    }

    /// Releases whatever the controller held when it went away.
    public func controllerDisconnected(_ controller: Int, at time: TimeInterval) {
        send(ControllerSnapshot(), from: controller, at: time)
        send(RemoteSnapshot(), from: controller, at: time)
        adapters[controller] = nil
    }

    /// The focus engine moved focus onto or off the map, for example when
    /// a sheet opened or closed. Keeps the mapper's owner in step.
    public func focusMoved(toMap onMap: Bool, at time: TimeInterval) {
        if onMap {
            focusesInspector = false
        }
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

    /// The demolish confirmation closed: the remote returns to the map.
    public func demolishConfirmationClosed(at time: TimeInterval) {
        guard mapper.focus == .hud else { return }
        send(.focusChanged(.map), at: time)
        applyEffect?(.focusMap)
    }

    /// Controller input acts only while the map owns the remote; in the
    /// HUD the focus engine handles the same presses (design D3). The
    /// adapter still sees every snapshot, so its edges stay correct.
    private func forward(_ inputs: [RemoteInput], at time: TimeInterval) {
        guard mapper.focus == .map else { return }
        for input in inputs {
            send(input, at: time)
        }
    }

    /// Opens the map overview from the HUD and hands the remote to the
    /// map, so the overview gets its input and Back closes it instead of
    /// leaving the app. Spec: `platform-shells` / Apple TV map overview.
    public func openOverview(at time: TimeInterval) {
        guard session.overview == nil else { return }
        focusMoved(toMap: true, at: time)
        // The mapper opens it, as for a controller's X, and asks the host
        // to focus the map.
        send(.overview, at: time)
    }

    /// The inspector callout holds focus, so the HUD can take part again.
    public func inspectorTookFocus() {
        focusesInspector = false
    }

    private func apply(_ effects: [RemoteEffect], at time: TimeInterval) {
        for effect in effects {
            if effect == .focusInspector {
                focusesInspector = true
            }
            applyEffect?(effect)
        }
        if mapper.focus != focus {
            focus = mapper.focus
        }
        let tooltip = mapper.tooltipBuilding(at: time, session: session)
        if tooltip != tooltipBuilding {
            tooltipBuilding = tooltip
        }
    }
}
