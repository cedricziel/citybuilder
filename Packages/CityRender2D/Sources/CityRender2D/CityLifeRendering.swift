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

    /// Marks a glow that goes dark late at night (a house whose household goes to bed).
    static let glowSleepsKey = "sleeps"
    /// Marks a building with no window glow at all (a workshop without lights art).
    static let noWindowGlowKey = "noWindowGlow"

    /// Warm windows on inhabited houses and working buildings,
    /// brightening as night falls. Spec: `rendering-2_5d` / Lit windows
    /// follow the lights art. The lights name and whether the household
    /// goes to bed are resolved once, when the glow is made; by day a
    /// building without a glow costs nothing.
    func updateWindowGlow(with snapshot: WorldSnapshot) {
        let time = TimeOfDay(tick: snapshot.tickCount)
        let glow = CGFloat(time.darkness / TimeOfDay.nightDarkness) * WindowLights.strength
        let bedtime = WindowLights.bedtime(at: time)
        for (spec, node) in presentSprites {
            guard case let .building(kind, state, _, _, _, _, _, _, _, _) = spec.kind,
                  state == .operational, kind != .road
            else { continue }
            let lit = glow > 0 && isLit(kind: kind, at: spec.coord, in: snapshot)
            let shown = node.childNode(withName: Self.windowGlowNodeName)
            guard shown != nil || lit else { continue }
            guard let glowNode = shown ?? makeGlow(for: node, kind: kind, id: snapshot.occupiedTiles[spec.coord]) else { continue }
            let sleeps = glowNode.userData?[Self.glowSleepsKey] as? Bool ?? false
            glowNode.alpha = lit ? glow * (sleeps ? 1 - bedtime : 1) : 0
        }
    }

    /// The building's window glow, added to it: its lights art, else two panes for a house. Nil, and
    /// remembered on the building, when a workshop has no lights art.
    private func makeGlow(for node: SKNode, kind: BuildingKind, id: EntityID?) -> SKNode? {
        guard let sprite = node as? SKSpriteNode, sprite.userData?[Self.noWindowGlowKey] == nil else { return nil }
        let lights = lightsTextureName(for: sprite, kind: kind, id: id)
        guard kind == .house || lights != nil else {
            if sprite.userData == nil { sprite.userData = [:] }
            sprite.userData?[Self.noWindowGlowKey] = true
            return nil
        }
        let made = lights.map(makeLightsGlow(named:)) ?? makeWindowGlow(spriteSize: sprite.size)
        // Late at night most houses go to bed; workshops keep working.
        made.userData = [Self.glowSleepsKey: kind == .house && !(id.map(WindowLights.staysUp) ?? true)]
        node.addChild(made)
        return made
    }

    /// Inhabited for a house; otherwise working: a rival's operational
    /// building, or a player's with no issue.
    private func isLit(kind: BuildingKind, at coord: TileCoordinate, in snapshot: WorldSnapshot) -> Bool {
        guard let id = snapshot.occupiedTiles[coord] else { return false }
        if kind == .house { return (snapshot.housePopulations[id]?.population ?? 0) > 0 }
        guard let building = snapshot.buildings[id] else { return false }
        return building.owner != .player || snapshot.buildingIssues[id] == nil
    }

    /// This building's `<sprite stem>-lights-<n>`, else `<sprite stem>-lights`, when the atlas has it,
    /// remembered per name tried.
    private func lightsTextureName(for sprite: SKSpriteNode, kind: BuildingKind, id: EntityID?) -> String? {
        let stem = (sprite.userData?[Self.textureNameKey] as? String).map(TextureFiltering.stem(of:)) ?? "building-\(kind.rawValue)"
        let candidates = WindowLights.candidates(stem: stem, id: id)
        if let known = lightsNames[candidates[0]] { return known }
        let found = candidates.first(where: hasSprite)
        lightsNames[candidates[0]] = .some(found)
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
            if strollerNodes[key]?.facing != facing || strollerNodes[key]?.walking != walking {
                node.playWalkCycle(.walker(facing), frames: SpriteAtlas.walkerAnimation(facing: facing), moving: walking)
                strollerNodes[key] = StrollerVisual(node: node, facing: facing, walking: walking)
            }
            // Feet on the tile centre, like carriers, sorted by where they stand right now.
            let along = stroller.progress
            node.position = IsoMath.screenPoint(
                forTileFractionalX: Double(stroller.from.x) + 0.5 + Double(stroller.to.x - stroller.from.x) * along,
                fractionalY: Double(stroller.from.y) + 0.5 + Double(stroller.to.y - stroller.from.y) * along
            )
            node.zPosition = Self.figureZ(at: node.position)
        }
    }
}

/// A stroller's node and the facing and walk state it shows.
struct StrollerVisual {
    let node: SKSpriteNode
    let facing: SpriteAtlas.WalkerFacing
    let walking: Bool
}

struct StrollerKey: Hashable {
    let house: EntityID
    let slot: Int
}
