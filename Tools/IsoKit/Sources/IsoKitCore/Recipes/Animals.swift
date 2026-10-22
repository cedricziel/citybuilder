// isokit: animals for ambient life. Built facing +x from primitives like the people, then turned to a facing.
import AppKit
import SceneKit

enum Hide {
    static let wool = NSColor(red: 0.70, green: 0.69, blue: 0.64, alpha: 1)
    static let sheepFace = NSColor(red: 0.18, green: 0.16, blue: 0.15, alpha: 1)
    static let dun = NSColor(red: 0.42, green: 0.33, blue: 0.26, alpha: 1)
    static let pied = NSColor(red: 0.70, green: 0.68, blue: 0.62, alpha: 1)
    static let hoof = NSColor(red: 0.14, green: 0.12, blue: 0.11, alpha: 1)
    static let horn = NSColor(red: 0.72, green: 0.66, blue: 0.54, alpha: 1)
    static let hen = NSColor(red: 0.56, green: 0.36, blue: 0.22, alpha: 1)
    static let comb = NSColor(red: 0.62, green: 0.18, blue: 0.14, alpha: 1)
}

/// A four-legged grazer: an ellipsoid body on four legs, a neck and a head. Sizes in metres.
struct Beast {
    var length: CGFloat
    var withers: CGFloat
    var girth: CGFloat
    var coat: NSColor
    /// Legs, neck and head: dark on a sheep, the coat on a cow.
    var points: NSColor
    var patch: NSColor?
    var horns = false
    var tail: CGFloat = 0.5

    static let sheep = Beast(length: 1.1, withers: 0.7, girth: 0.3, coat: Hide.wool, points: Hide.sheepFace, tail: 0.15)
    static let cow = Beast(length: 2.0, withers: 1.35, girth: 0.5, coat: Hide.dun, points: Hide.dun, patch: Hide.pied, horns: true)
}

/// Walking, or grazing with the head down and the jaw working.
enum Gait {
    case walk(CGFloat), graze(CGFloat)
}

extension Builder {
    func beast(_ beast: Beast, _ gait: Gait) {
        let half = beast.length / 2, legTop = beast.withers - beast.girth * 0.7
        var swing: CGFloat = 0, chew: CGFloat = 0, grazing = false
        switch gait {
        case let .walk(phase): swing = 2 * .pi * phase
        case let .graze(phase): grazing = true; chew = sin(2 * .pi * phase)
        }
        let bob = grazing ? 0 : 0.02 * cos(2 * swing)
        // Diagonal pairs swing together: near fore with far hind.
        for (end, side, offset) in [(CGFloat(1), CGFloat(1), CGFloat(0)), (1, -1, .pi), (-1, 1, .pi), (-1, -1, 0)] {
            let angle = grazing ? 0 : 0.32 * sin(swing + offset)
            let top = SCNVector3(end * half * 0.72, legTop + bob, side * beast.girth * 0.55)
            let hoof = top + SCNVector3(sin(angle) * legTop, -cos(angle) * legTop, 0)
            limb(top, hoof, radius: beast.girth * 0.17, beast.points)
            ball(hoof + SCNVector3(0, 0.03, 0), radius: beast.girth * 0.16, Hide.hoof)
        }
        let centre = SCNVector3(0, beast.withers - beast.girth * 0.15 + bob, 0)
        ball(centre, radius: 1, beast.coat, scale: SCNVector3(half, beast.girth, beast.girth * 0.9))
        if let patch = beast.patch {
            let flank = SCNVector3(half * 0.45, beast.girth * 0.8, beast.girth * 0.95)
            ball(centre + SCNVector3(-half * 0.2, beast.girth * 0.25, 0), radius: 1, patch, scale: flank)
        }
        let shoulder = centre + SCNVector3(half * 0.8, beast.girth * 0.3, 0)
        let head = grazing
            ? SCNVector3(half * 1.15, 0.12 + 0.03 * chew, 0)
            : shoulder + SCNVector3(half * 0.35, beast.girth * 0.9, 0)
        limb(shoulder, head, radius: beast.girth * 0.38, beast.points)
        let skull = ball(head, radius: beast.girth * 0.42, beast.points, scale: SCNVector3(1.35, 0.85, 0.8))
        skull.eulerAngles = SCNVector3(0, 0, grazing ? -1.0 : -0.35)
        if beast.horns {
            for side in [CGFloat(1), -1] {
                let root = head + SCNVector3(-0.05, beast.girth * 0.3, side * 0.08)
                limb(root, head + SCNVector3(0, beast.girth * 0.55, side * 0.3), radius: 0.03, Hide.horn)
            }
        }
        let rump = centre + SCNVector3(-half * 0.98, beast.girth * 0.3, 0)
        limb(rump, rump + SCNVector3(-0.08, -beast.tail, 0), radius: beast.girth * 0.07, beast.coat)
    }

    /// A hen: a round body, a cocked tail and a comb; `peck` 0…1 lowers the head to the ground.
    func hen(_ peck: CGFloat) {
        ball(SCNVector3(0, 0.2, 0), radius: 0.13, Hide.hen, scale: SCNVector3(1.2, 0.95, 0.85))
        limb(SCNVector3(-0.12, 0.25, 0), SCNVector3(-0.2, 0.38, 0), radius: 0.05, Hide.hen)
        let head = SCNVector3(0.15 + 0.06 * peck, 0.34 - 0.2 * peck, 0)
        ball(head, radius: 0.06, Hide.hen)
        ball(head + SCNVector3(0, 0.06, 0), radius: 0.03, Hide.comb)
        for side in [CGFloat(1), -1] {
            limb(SCNVector3(0, 0.1, side * 0.05), SCNVector3(0, 0, side * 0.05), radius: 0.015, Hide.horn)
        }
    }
}
