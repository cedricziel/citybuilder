import Foundation

/// One reading of an extended game controller. Spec: `tv-remote-controls`
/// / Game controller mapping.
public struct ControllerSnapshot: Sendable {
    public var leftStick: (x: Double, y: Double)
    public var dpad: RemoteDirection?
    public var buttonA, buttonB, buttonX, buttonY, menu: Bool
    public var leftTrigger, rightTrigger: Double

    public init(
        leftStick: (x: Double, y: Double) = (0, 0), dpad: RemoteDirection? = nil,
        buttonA: Bool = false, buttonB: Bool = false, buttonX: Bool = false, buttonY: Bool = false, menu: Bool = false,
        leftTrigger: Double = 0, rightTrigger: Double = 0
    ) {
        self.leftStick = leftStick
        self.dpad = dpad
        self.buttonA = buttonA
        self.buttonB = buttonB
        self.buttonX = buttonX
        self.buttonY = buttonY
        self.menu = menu
        self.leftTrigger = leftTrigger
        self.rightTrigger = rightTrigger
    }
}

/// One reading of the Siri Remote: the touch position on the clickpad
/// (nil when no finger rests on it), whether the clickpad is pressed, and
/// the Play/Pause and Back buttons.
public struct RemoteSnapshot: Sendable {
    public var touch: (x: Double, y: Double)?
    public var pressed, playPause, menu: Bool

    public init(touch: (x: Double, y: Double)? = nil, pressed: Bool = false, playPause: Bool = false, menu: Bool = false) {
        self.touch = touch
        self.pressed = pressed
        self.playPause = playPause
        self.menu = menu
    }
}

/// Turns controller and remote button-state snapshots into the mapper's
/// events, so the mapping runs on any platform. Only the GameController
/// callbacks that produce the snapshots are tvOS code. Design D3, D4.
public struct GameControllerAdapter: Sendable {
    /// Screen points per unit of touch travel; tuned on hardware (6.1).
    public static let touchGain = 900.0
    /// Screen points per update at full stick deflection.
    public static let stickGain = 24.0
    public static let stickDeadZone = 0.15
    /// A clickpad press this far from the center is an edge click.
    public static let edgeThreshold = 0.5
    /// A UIKit press repeating a GameController event within this window
    /// is the same press arriving twice.
    public static let duplicateWindow: TimeInterval = 0.05

    private var controller = ControllerSnapshot()
    private var remote = RemoteSnapshot()
    private var remoteSelecting = false
    private var lastEmitted: [RemoteInput: TimeInterval] = [:]

    public init() {}

    public mutating func update(_ next: ControllerSnapshot, at time: TimeInterval) -> [RemoteInput] {
        var inputs: [RemoteInput] = []
        if next.dpad != controller.dpad, let direction = next.dpad {
            inputs.append(.click(direction))
        }
        inputs += Self.edges(controller.buttonA, next.buttonA, down: .selectDown, up: .selectUp)
        if next.buttonB, !controller.buttonB { inputs.append(.back) }
        if next.buttonX, !controller.buttonX { inputs.append(.overview) }
        inputs += Self.edges(controller.buttonY, next.buttonY, down: .playPauseDown, up: .playPauseUp)
        if next.menu, !controller.menu { inputs.append(.menu) }
        let (stickX, stickY) = next.leftStick
        if max(abs(stickX), abs(stickY)) > Self.stickDeadZone {
            inputs.append(.swipe(dx: stickX * Self.stickGain, dy: -stickY * Self.stickGain))
        }
        let zoom = next.rightTrigger - next.leftTrigger
        if zoom != 0 { inputs.append(.zoomAxis(zoom)) }
        controller = next
        return record(inputs, at: time)
    }

    public mutating func update(_ next: RemoteSnapshot, at time: TimeInterval) -> [RemoteInput] {
        var inputs: [RemoteInput] = []
        if let touch = next.touch, let previous = remote.touch, !next.pressed {
            let dx = (touch.x - previous.x) * Self.touchGain
            let dy = -(touch.y - previous.y) * Self.touchGain
            if dx != 0 || dy != 0 { inputs.append(.swipe(dx: dx, dy: dy)) }
        }
        if next.pressed, !remote.pressed {
            if let direction = Self.edgeDirection(next.touch) {
                inputs.append(.click(direction))
            } else {
                remoteSelecting = true
                inputs.append(.selectDown)
            }
        } else if !next.pressed, remote.pressed, remoteSelecting {
            remoteSelecting = false
            inputs.append(.selectUp)
        }
        inputs += Self.edges(remote.playPause, next.playPause, down: .playPauseDown, up: .playPauseUp)
        if next.menu, !remote.menu { inputs.append(.back) }
        remote = next
        return record(inputs, at: time)
    }

    /// A press from UIKit, or nil when GameController already reported it.
    /// The simulator's remote sends only UIKit presses; on hardware both
    /// paths can see one press. Design D3.
    public func uiKitPress(_ input: RemoteInput, at time: TimeInterval) -> RemoteInput? {
        if let emitted = lastEmitted[input], time - emitted < Self.duplicateWindow { return nil }
        return input
    }

    private mutating func record(_ inputs: [RemoteInput], at time: TimeInterval) -> [RemoteInput] {
        for input in inputs {
            lastEmitted[input] = time
        }
        return inputs
    }

    private static func edges(_ was: Bool, _ now: Bool, down: RemoteInput, up: RemoteInput) -> [RemoteInput] {
        if now, !was { return [down] }
        if was, !now { return [up] }
        return []
    }

    private static func edgeDirection(_ touch: (x: Double, y: Double)?) -> RemoteDirection? {
        guard let (x, y) = touch, max(abs(x), abs(y)) > edgeThreshold else { return nil }
        if abs(x) > abs(y) { return x > 0 ? .right : .left }
        return y > 0 ? .up : .down
    }
}
