import CityCore
import CoreGraphics
import Foundation
import SpriteKit

/// Foam behind a moving ship. Spec: `rendering-2_5d` / Ships leave a wake.
enum ShipWake {
    static let emitterName = "wake"
    static let stopKey = "wakeStop"
    /// The wake stops this long after the ship's last move.
    static let stopAfter: TimeInterval = 0.3
    static let birthRate: CGFloat = 16
    static let speed: CGFloat = 7
    static let lifetime: CGFloat = 2
    /// Over the water, under the buildings (10+) and ships.
    static let layerZ: CGFloat = 6

    /// Screen-space unit vector the ship points along. World heading 0 is
    /// +x (screen down-right), π/2 is +y (screen down-left).
    static func screenDirection(heading: Fixed) -> CGVector {
        let angle = Double(heading.raw) / Double(Fixed.scale)
        let tile = (x: cos(angle), y: sin(angle))
        let dx = (tile.x - tile.y) * Double(IsoMath.tileWidth / 2)
        let dy = -(tile.x + tile.y) * Double(IsoMath.tileHeight / 2)
        let length = max(0.0001, (dx * dx + dy * dy).squareRoot())
        return CGVector(dx: dx / length, dy: dy / length)
    }

    /// A wake emitter, idle until the ship moves. Its puffs are left in
    /// `layer`, so the foam stays where it was laid.
    static func makeEmitter(in layer: SKNode) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.name = emitterName
        emitter.targetNode = layer
        emitter.particleTexture = AmbientLayerNode.puffTexture
        emitter.particleBirthRate = 0
        emitter.particlePositionRange = CGVector(dx: 3, dy: 2)
        emitter.emissionAngleRange = 1.3
        emitter.particleScale = 0.1
        emitter.particleScaleRange = 0.03
        emitter.particleScaleSpeed = 0.12
        emitter.particleAlpha = 0.55
        emitter.particleAlphaRange = 0.1
        emitter.particleColor = SKColor(white: 0.96, alpha: 1)
        emitter.particleColorBlendFactor = 1
        emitter.particleBlendMode = .alpha
        return emitter
    }

    /// Points the emitter out of the stern and starts it; it stops again
    /// `stopAfter` seconds after the last call.
    static func lay(_ emitter: SKEmitterNode, heading: Fixed, reduceMotion: Bool, zoomedOut: Bool) {
        let ahead = screenDirection(heading: heading)
        let motion: CGFloat = reduceMotion ? 0.5 : 1
        emitter.position = CGPoint(x: -ahead.dx * 14, y: -ahead.dy * 14)
        emitter.emissionAngle = atan2(-ahead.dy, -ahead.dx)
        emitter.particleBirthRate = birthRate * motion
        emitter.particleSpeed = speed * motion
        emitter.particleSpeedRange = speed * 0.4 * motion
        emitter.particleLifetime = zoomedOut ? lifetime / 2 : lifetime
        emitter.particleAlphaSpeed = -emitter.particleAlpha / emitter.particleLifetime
        emitter.run(.sequence([.wait(forDuration: stopAfter), .run { [weak emitter] in
            emitter?.particleBirthRate = 0
        }]), withKey: stopKey)
    }
}
