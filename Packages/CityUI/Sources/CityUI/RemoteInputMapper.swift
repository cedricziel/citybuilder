import CityCore
import Foundation

/// Which part of the screen owns the remote. Spec: `tv-remote-controls`
/// / One input owner per mode.
public enum RemoteFocus: Hashable, Sendable {
    case map, hud
}

/// One normalised event from the Siri Remote or a game controller.
/// Design D4.
public enum RemoteInput: Equatable, Sendable {
    /// Screen points the reticle should travel across the map.
    case swipe(dx: Double, dy: Double)
    case click(RemoteDirection)
    case selectDown, selectUp
    case playPauseDown, playPauseUp
    case back
    /// A controller's Menu button.
    case menu
    /// Trigger zoom, -1 (out) to 1 (in), sent once per controller update.
    case zoomAxis(Double)
    case focusChanged(RemoteFocus)
    /// The host's frame clock; lets holds fire while a button is down.
    case tick
}

/// What the view layer does in response to an input.
public enum RemoteEffect: Equatable, Sendable {
    case focusHUD, focusMap
}

/// Turns remote and controller input into `GameSession` calls and focus
/// changes. Platform-neutral, with time passed in, so the macOS test run
/// covers every rule. Design D4.
@MainActor
public struct RemoteInputMapper {
    /// A press held this long is a hold rather than a click.
    public static let holdDuration: TimeInterval = 0.4
    /// Zoom factor per controller update at full trigger.
    static let triggerZoomRate = 0.03

    public private(set) var focus: RemoteFocus = .map
    private var playPauseDownAt: TimeInterval?

    public init() {}

    public mutating func handle(_ input: RemoteInput, at time: TimeInterval, session: GameSession) -> [RemoteEffect] {
        switch input {
        case let .focusChanged(newFocus):
            focus = newFocus
        case .playPauseDown:
            playPauseDownAt = time
        case .playPauseUp:
            return playPauseReleased(at: time, session: session)
        case .tick:
            holdPlayPauseIfDue(at: time, session: session)
        case let .swipe(dx, dy) where focus == .map:
            session.handlePanDelta(deltaX: -dx, deltaY: -dy)
        case let .click(direction) where focus == .map:
            session.stepCamera(direction)
        case let .zoomAxis(value) where focus == .map:
            session.world.camera.multiplyZoom(by: 1 + Self.triggerZoomRate * value)
        default:
            break
        }
        return []
    }

    private mutating func holdPlayPauseIfDue(at time: TimeInterval, session: GameSession) {
        guard let downAt = playPauseDownAt, time - downAt >= Self.holdDuration else { return }
        playPauseDownAt = nil
        if focus == .map {
            session.cycleZoomLevel()
        }
    }

    /// A short press moves focus between the map and the HUD. Design D7.
    private mutating func playPauseReleased(at time: TimeInterval, session: GameSession) -> [RemoteEffect] {
        holdPlayPauseIfDue(at: time, session: session)
        guard playPauseDownAt != nil else { return [] }
        playPauseDownAt = nil
        switch focus {
        case .map:
            focus = .hud
            return [.focusHUD]
        case .hud:
            focus = .map
            return [.focusMap]
        }
    }
}
