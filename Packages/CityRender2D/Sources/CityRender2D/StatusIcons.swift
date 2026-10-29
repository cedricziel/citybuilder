import CityCore
import CoreGraphics
import SpriteKit

/// The icon that floats over a building while something is wrong. Spec: `rendering-2_5d` /
/// Buildings show a status icon while something is wrong. Design canvas:
/// https://claude.ai/artifact/JMuRyVB1tHAFthEbFxdE2F (option A, "Disc").
enum StatusIcons {
    static let nodeName = "status-icon"
    static let bobKey = "bob"

    // The disc's diameter in points at zoom 1.
    #if os(tvOS)
    static let discPoints: CGFloat = 30
    #elseif os(iOS)
    static let discPoints: CGFloat = 22
    #else
    static let discPoints: CGFloat = 20
    #endif
    /// The disc's share of the icon's cell: a 24-point disc on a 28-point cell.
    static let discFraction: CGFloat = 24.0 / 28.0
    /// The icon's cell at zoom 1, in points, before its zoom scale.
    static let side = discPoints / discFraction
    /// The icon's on-screen size follows the zoom within these bounds, so it shrinks less than the world.
    static let zoomRange: ClosedRange<CGFloat> = 0.75 ... 1.25
    /// The smallest touch target around an icon, in on-screen points.
    static let hitPoints: CGFloat = 44
    /// Gap between the sprite's top and the icon's bottom, in points.
    static let lift: CGFloat = 2

    /// The icon a building's issue calls for. Exhaustive, so a new issue case has to choose one.
    static func textureName(for issue: BuildingIssue) -> String? {
        switch issue {
        case .noRoad: "status-no-road"
        case .noRouteToStorage: "status-no-route"
        case .noTreesInReach: "status-no-trees"
        case .noRoomToPlant: "status-no-room-to-plant"
        case let .missingInputs(goods): goods.first.map(short)
        case let .outputStuck(good): stuck(good)
        }
    }

    /// What a seasonal event does to a building (`add-event-counterplay`): it burns, it is ruins to
    /// clear, its field is blighted, or fever holds its house back.
    enum Hazard: String, CaseIterable {
        case burning, ruins, blight, fever
    }

    /// The hazard's icon: the flame and the ruins on the red disc, the blight and the fever on the
    /// cream one with a pip.
    static func textureName(for hazard: Hazard) -> String {
        "status-\(hazard.rawValue)"
    }

    /// The good on a cream disc with a red "!": a missing input or an unmet house need.
    static func short(_ good: Good) -> String {
        "status-\(good.rawValue)-short"
    }

    /// The good with an amber pause: output with nowhere to go.
    static func stuck(_ good: Good) -> String {
        "status-\(good.rawValue)-stuck"
    }

    /// The icon for each of the player's buildings that needs one: a fire or ruins first, then its
    /// issue, else a house's first short need in `Good` order, else no road.
    static func icons(in snapshot: WorldSnapshot) -> [EntityID: String] {
        let isPlayers = { (id: EntityID) in snapshot.buildings[id]?.owner == .player }
        var icons: [EntityID: String] = [:]
        for id in snapshot.roadDisconnectedBuildings where isPlayers(id) {
            icons[id] = textureName(for: .noRoad)
        }
        for (id, population) in snapshot.housePopulations where isPlayers(id) {
            if let good = Good.allCases.first(where: population.isShort) { icons[id] = short(good) }
        }
        for (id, issue) in snapshot.buildingIssues where isPlayers(id) {
            if let name = textureName(for: issue) { icons[id] = name }
        }
        for building in snapshot.buildings.values where building.owner == .player {
            if building.state == .burning {
                icons[building.id] = textureName(for: .burning)
            } else if building.kind == .ruins {
                icons[building.id] = textureName(for: .ruins)
            }
        }
        return icons
    }

    /// Node scale that keeps the on-screen size at `clamp(zoom)` of its zoom-1 size.
    static func scale(zoom: Double) -> CGFloat {
        let zoom = CGFloat(zoom)
        guard zoom > 0 else { return 1 }
        return min(max(zoom, zoomRange.lowerBound), zoomRange.upperBound) / zoom
    }

    /// A 2 pt bob over 1.8 s, started part-way through by the building's id so a street of icons
    /// does not move in step. `scale` is the icon's zoom scale, so the bob follows the icon's size.
    static func bob(for id: EntityID, scale: CGFloat) -> SKAction {
        let half = SKAction.moveBy(x: 0, y: 2 * scale, duration: 0.9)
        half.timingMode = .easeInEaseOut
        let phase = Double(UInt64(id.raw) &* 0x9E37_79B9 % 18) / 10
        return .sequence([.wait(forDuration: phase), .repeatForever(.sequence([half, half.reversed()]))])
    }

    /// Over the roof: the top of the sprite's opaque pixels, since a render's cell leaves headroom.
    static func restPosition(on sprite: SKSpriteNode, scale: CGFloat) -> CGPoint {
        CGPoint(x: 0, y: sprite.size.height * contentTop(of: sprite.texture) + lift * scale)
    }

    private nonisolated(unsafe) static var contentTops: [ObjectIdentifier: CGFloat] = [:]

    /// The height of a texture's topmost opaque row, as a fraction of its height (1 when it has
    /// no image to read, as in tests), measured once per texture.
    static func contentTop(of texture: SKTexture?) -> CGFloat {
        guard let texture else { return 1 }
        let key = ObjectIdentifier(texture)
        if let top = contentTops[key] { return top }
        let top = measureContentTop(texture.cgImage())
        contentTops[key] = top
        return top
    }

    static func measureContentTop(_ image: CGImage) -> CGFloat {
        let width = image.width, height = image.height
        guard width > 0, height > 0,
              let context = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ),
              let data = context.data
        else { return 1 }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        // Row 0 of the bitmap is the image's top row.
        for row in 0 ..< height {
            for column in 0 ..< width where pixels[(row * width + column) * 4 + 3] > 32 {
                return CGFloat(height - row) / CGFloat(height)
            }
        }
        return 1
    }

    static func make(named name: String, on sprite: SKSpriteNode, id: EntityID, zoom: Double, reduceMotion: Bool) -> SKSpriteNode {
        let icon = SKSpriteNode(texture: SpriteAtlas.textureOrPlaceholder(named: name), size: CGSize(width: side, height: side))
        icon.name = nodeName
        icon.userData = [IsoWorldScene.textureNameKey: name]
        icon.anchorPoint = CGPoint(x: 0.5, y: 0)
        icon.zPosition = 100 // over the night shade (95), like the construction badge
        icon.alpha = 0
        icon.run(.fadeIn(withDuration: 0.2))
        settle(icon, on: sprite, id: id, scale: scale(zoom: zoom), reduceMotion: reduceMotion)
        return icon
    }

    /// Sizes the icon for the zoom, puts it back at rest and restarts its bob, if any.
    static func settle(_ icon: SKSpriteNode, on sprite: SKSpriteNode, id: EntityID, scale: CGFloat, reduceMotion: Bool) {
        icon.removeAction(forKey: bobKey)
        icon.setScale(scale)
        icon.position = restPosition(on: sprite, scale: scale)
        if !reduceMotion { icon.run(bob(for: id, scale: scale), withKey: bobKey) }
    }
}

extension IsoWorldScene {
    /// Adds, retextures and removes the status icons of the buildings on screen. One node per
    /// building at most; a node is only touched when its icon, the zoom or Reduce Motion changes.
    func reconcileStatusIcons(with snapshot: WorldSnapshot) {
        let wanted = StatusIcons.icons(in: snapshot)
        let scale = StatusIcons.scale(zoom: snapshot.camera.zoom)
        let gone = statusIcons.filter { id, icon in
            let sprite = snapshot.buildings[id].flatMap { buildingNodes[$0.anchor] }
            return wanted[id] == nil || sprite == nil || icon.parent !== sprite
        }
        for (id, icon) in gone {
            icon.removeFromParent()
            statusIcons.removeValue(forKey: id)
        }
        for (id, name) in wanted {
            guard let building = snapshot.buildings[id], let sprite = buildingNodes[building.anchor] else { continue }
            guard let icon = statusIcons[id] else {
                let icon = StatusIcons.make(named: name, on: sprite, id: id, zoom: snapshot.camera.zoom, reduceMotion: reduceMotion)
                sprite.addChild(icon)
                statusIcons[id] = icon
                continue
            }
            if icon.userData?[Self.textureNameKey] as? String != name {
                icon.texture = SpriteAtlas.textureOrPlaceholder(named: name)
                icon.userData?[Self.textureNameKey] = name
            }
            let bobbing = icon.action(forKey: StatusIcons.bobKey) != nil
            if icon.xScale != scale || bobbing == reduceMotion {
                StatusIcons.settle(icon, on: sprite, id: id, scale: scale, reduceMotion: reduceMotion)
            }
        }
    }

    /// The anchor of the building whose status icon covers `sceneLocation`, with the hit area
    /// grown to 44 on-screen points. Where hit areas overlap, the icon whose centre is nearest wins.
    func statusIconTile(at sceneLocation: CGPoint) -> TileCoordinate? {
        guard let snapshot = dataSource?.currentSnapshot() else { return nil }
        let screenPerLocal = CGFloat(snapshot.camera.zoom)
        var best: (anchor: TileCoordinate, distance: CGFloat)?
        for (id, icon) in statusIcons {
            guard let building = snapshot.buildings[id], icon.scene === self else { continue }
            let point = convert(sceneLocation, to: icon)
            // In the icon's own, unscaled units.
            let side = StatusIcons.side
            let reach = max(side, StatusIcons.hitPoints / (screenPerLocal * icon.xScale)) / 2
            let offset = CGPoint(x: point.x, y: point.y - side / 2)
            guard abs(offset.x) <= reach, abs(offset.y) <= reach else { continue }
            let distance = hypot(offset.x, offset.y) * icon.xScale
            if distance < best?.distance ?? .infinity { best = (building.anchor, distance) }
        }
        return best?.anchor
    }
}
