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

    /// Warm windows on inhabited houses and working buildings,
    /// brightening as night falls. Spec: `rendering-2_5d` / Lit windows
    /// follow the lights art.
    func updateWindowGlow(with snapshot: WorldSnapshot) {
        let glow = CGFloat(TimeOfDay(tick: snapshot.tickCount).darkness / TimeOfDay.nightDarkness)
        for (spec, node) in presentSprites {
            guard case let .building(kind, state, _, _, _, _, _, _, _, _) = spec.kind,
                  state == .operational, kind != .road, let sprite = node as? SKSpriteNode
            else { continue }
            let lights = lightsTextureName(for: sprite, kind: kind)
            guard kind == .house || lights != nil else { continue }
            let target = isLit(kind: kind, at: spec.coord, in: snapshot) ? glow : 0
            if let existing = node.childNode(withName: Self.windowGlowNodeName) {
                existing.alpha = target
            } else if target > 0 {
                let made = lights.map(makeLightsGlow(named:)) ?? makeWindowGlow(spriteSize: sprite.size)
                made.alpha = target
                node.addChild(made)
            }
        }
    }

    /// Inhabited for a house; otherwise working: a rival's operational
    /// building, or a player's with no issue.
    private func isLit(kind: BuildingKind, at coord: TileCoordinate, in snapshot: WorldSnapshot) -> Bool {
        guard let id = snapshot.occupiedTiles[coord] else { return false }
        if kind == .house { return (snapshot.housePopulations[id]?.population ?? 0) > 0 }
        guard let building = snapshot.buildings[id] else { return false }
        return building.owner != .player || snapshot.buildingIssues[id] == nil
    }

    /// `<sprite stem>-lights` when the atlas has it, remembered per stem.
    private func lightsTextureName(for sprite: SKSpriteNode, kind: BuildingKind) -> String? {
        let stem = (sprite.userData?[Self.textureNameKey] as? String).map(TextureFiltering.stem(of:)) ?? "building-\(kind.rawValue)"
        if let known = lightsNames[stem] { return known }
        let name = "\(stem)-lights"
        let found = hasSprite(name) ? name : nil
        lightsNames[stem] = .some(found)
        return found
    }

    /// The building's lights art, added over its sprite.
    private func makeLightsGlow(named name: String) -> SKNode {
        let glow = SKSpriteNode(texture: SpriteAtlas.textureOrPlaceholder(named: name))
        glow.name = Self.windowGlowNodeName
        glow.anchorPoint = CGPoint(x: 0.5, y: 0)
        glow.blendMode = .add
        glow.zPosition = 96
        return glow
    }

    /// Two warm panes on the front walls, a third of the way up the
    /// sprite (whose anchor is its bottom centre).
    private func makeWindowGlow(spriteSize: CGSize) -> SKNode {
        let glow = SKNode()
        glow.name = Self.windowGlowNodeName
        for side in [-1.0, 1.0] {
            let pane = SKSpriteNode(color: SKColor(red: 1, green: 0.78, blue: 0.35, alpha: 1), size: CGSize(width: 3, height: 4))
            pane.position = CGPoint(x: side * spriteSize.width * 0.18, y: spriteSize.height * 0.3)
            pane.blendMode = .add
            glow.addChild(pane)
        }
        glow.zPosition = 96
        return glow
    }

    func reconcileStrollers(with snapshot: WorldSnapshot, now: TimeInterval) {
        let wanted = StrollerPlanner.strollers(in: snapshot)
        let keys = Set(wanted.map { StrollerKey(house: $0.house, slot: $0.slot) })
        for (key, shown) in strollerNodes where !keys.contains(key) {
            shown.node.removeFromParent()
            strollerNodes.removeValue(forKey: key)
        }
        let walking = !simulationIsStill(now: now)
        for stroller in wanted {
            let key = StrollerKey(house: stroller.house, slot: stroller.slot)
            let facing = stroller.facing
            let node: SKSpriteNode
            if let shown = strollerNodes[key] {
                node = shown.node
            } else {
                node = SKSpriteNode.walker()
                addChild(node)
            }
            // Lit sprites are never mirrored: each facing plays its own frames. Paused, they stand.
            if strollerNodes[key]?.facing != facing || node.isWalking != walking {
                node.playWalkCycle(.walker(facing), frames: SpriteAtlas.walkerAnimation(facing: facing), moving: walking)
                strollerNodes[key] = (node, facing)
            }
            let from = IsoMath.screenPoint(forTile: stroller.from)
            let to = IsoMath.screenPoint(forTile: stroller.to)
            let along = CGFloat(stroller.progress)
            node.position = CGPoint(x: from.x + (to.x - from.x) * along, y: from.y + (to.y - from.y) * along)
            let depth = Double(max(stroller.from.x + stroller.from.y, stroller.to.x + stroller.to.y) + 1)
            node.zPosition = Self.depthZ(depth) + Self.figureLift
        }
    }
}

struct StrollerKey: Hashable {
    let house: EntityID
    let slot: Int
}
