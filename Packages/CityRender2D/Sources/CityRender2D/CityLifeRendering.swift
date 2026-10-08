import CityCore
import SpriteKit

/// Night, lit windows and strollers. Spec: `rendering-2_5d` / Night
/// falls on the scene, Residents stroll the streets.
extension IsoWorldScene {
    static let windowGlowNodeName = "window-glow"

    /// Sets up the night overlay under the camera so it always covers
    /// the view. Called once from `didMove`/init.
    func installNightOverlay() {
        nightOverlay.color = SKColor(red: 0.05, green: 0.07, blue: 0.22, alpha: 1)
        nightOverlay.colorBlendFactor = 1
        nightOverlay.size = CGSize(width: 8192, height: 8192)
        nightOverlay.alpha = 0
        nightOverlay.zPosition = 95 // over buildings and walkers, under badges
        if nightOverlay.parent == nil {
            camera?.addChild(nightOverlay)
        }
    }

    func applyTimeOfDay(_ time: TimeOfDay) {
        nightOverlay.alpha = CGFloat(time.darkness)
    }

    /// Warm windows on inhabited houses, brightening as night falls.
    func updateWindowGlow(with snapshot: WorldSnapshot) {
        let glow = CGFloat(TimeOfDay(tick: snapshot.tickCount).darkness / TimeOfDay.nightDarkness)
        for (spec, node) in presentSprites {
            guard case let .building(kind, state, _, _, _, _, _, _) = spec.kind,
                  kind == .house, state == .operational
            else { continue }
            let inhabited = snapshot.occupiedTiles[spec.coord]
                .flatMap { snapshot.housePopulations[$0] }
                .map { $0.population > 0 } ?? false
            let target = inhabited ? glow : 0
            if let existing = node.childNode(withName: Self.windowGlowNodeName) {
                existing.alpha = target
            } else if target > 0 {
                let size = (node as? SKSpriteNode)?.size ?? CGSize(width: 64, height: 64)
                node.addChild(makeWindowGlow(alpha: target, spriteSize: size))
            }
        }
    }

    /// Two warm panes on the front walls, a third of the way up the
    /// sprite (whose anchor is its bottom centre).
    private func makeWindowGlow(alpha: CGFloat, spriteSize: CGSize) -> SKNode {
        let glow = SKNode()
        glow.name = Self.windowGlowNodeName
        for side in [-1.0, 1.0] {
            let pane = SKSpriteNode(color: SKColor(red: 1, green: 0.78, blue: 0.35, alpha: 1), size: CGSize(width: 3, height: 4))
            pane.position = CGPoint(x: side * spriteSize.width * 0.18, y: spriteSize.height * 0.3)
            pane.blendMode = .add
            glow.addChild(pane)
        }
        glow.zPosition = 96
        glow.alpha = alpha
        return glow
    }

    func reconcileStrollers(with snapshot: WorldSnapshot) {
        let wanted = StrollerPlanner.strollers(in: snapshot)
        let keys = Set(wanted.map { StrollerKey(house: $0.house, slot: $0.slot) })
        for (key, node) in strollerNodes where !keys.contains(key) {
            node.removeFromParent()
            strollerNodes.removeValue(forKey: key)
        }
        for stroller in wanted {
            let key = StrollerKey(house: stroller.house, slot: stroller.slot)
            let node = strollerNodes[key] ?? makeStrollerNode()
            if strollerNodes[key] == nil {
                addChild(node)
                strollerNodes[key] = node
            }
            let from = IsoMath.screenPoint(forTile: stroller.from)
            let to = IsoMath.screenPoint(forTile: stroller.to)
            let along = CGFloat(stroller.progress)
            node.position = CGPoint(x: from.x + (to.x - from.x) * along, y: from.y + (to.y - from.y) * along)
            node.xScale = stroller.to.x < stroller.from.x || stroller.to.y > stroller.from.y ? -1 : 1
        }
    }

    private func makeStrollerNode() -> SKSpriteNode {
        let frames = SpriteAtlas.walkerAnimation(facing: .se) ?? []
        let node = SKSpriteNode(texture: frames.first)
        node.anchorPoint = CGPoint(x: 0.5, y: 0)
        node.zPosition = 50
        node.texture?.filteringMode = .nearest
        if frames.count > 1 {
            node.run(.repeatForever(.animate(with: frames, timePerFrame: 0.2)), withKey: "walk")
        }
        return node
    }
}

struct StrollerKey: Hashable {
    let house: EntityID
    let slot: Int
}
