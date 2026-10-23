import SpriteKit

/// Whether the map's ambient motion runs, holds while the game is paused, or stops for Reduce
/// Motion. Tree sway and building animations follow it.
enum MotionState: Equatable {
    case running
    case held
    case stopped
}

extension IsoWorldScene {
    /// The motion state Reduce Motion and the pause call for at `now`.
    func motionState(now: TimeInterval) -> MotionState {
        reduceMotion ? .stopped : simulationIsStill(now: now) ? .held : .running
    }
}

/// Building animations follow the game like the rest of the map's life: they run, hold their frame
/// while the game is paused, and with Reduce Motion stand on their resting frame. Spec:
/// `rendering-2_5d` / Building animations follow pause and Reduce Motion.
@MainActor
enum BuildingMotion {
    /// Paused, a building holds its current frame; with Reduce Motion it shows the frame it was
    /// drawn with, operational frame 0.
    typealias State = MotionState

    static let key = "anim"
    /// The node's `userData` entry holding the texture it rests on.
    static let restKey = "animRest"

    /// Runs `action` on `node` as its animation, in `state`.
    static func arm(_ action: SKAction, on node: SKSpriteNode, state: State) {
        if node.userData == nil { node.userData = [:] }
        node.userData?[restKey] = node.texture
        node.run(action, withKey: key)
        apply(state, to: node)
    }

    /// Only the animation's own speed changes: badges, glows and pennants on the building keep theirs.
    static func apply(_ state: State, to node: SKSpriteNode) {
        guard let action = node.action(forKey: key) else { return }
        action.speed = state == .running ? 1 : 0
        if state == .stopped, let rest = node.userData?[restKey] as? SKTexture {
            node.texture = rest
        }
    }
}

extension IsoWorldScene {
    /// Runs, holds or stops every building animation on screen when the state changes.
    func updateBuildingMotion(now: TimeInterval) {
        let state = motionState(now: now)
        guard state != buildingMotionState else { return }
        buildingMotionState = state
        for node in buildingNodes.values {
            BuildingMotion.apply(state, to: node)
        }
    }
}
