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
        case .storageFull: "status-storage-full"
        case let .missingInputs(goods): goods.first.map(short)
        case let .resting(good): stuck(good)
        }
    }

    /// The good on a cream disc with a red "!": a missing input or an unmet house need.
    static func short(_ good: Good) -> String {
        "status-\(good.rawValue)-short"
    }

    /// The good with an amber pause: output with nowhere to go, or a producer resting on stock.
    static func stuck(_ good: Good) -> String {
        "status-\(good.rawValue)-stuck"
    }

    /// The icon for each of the player's buildings that needs one: its issue, else a house's first
    /// short need in `Good` order, else no road.
    static func icons(in snapshot: WorldSnapshot) -> [EntityID: String] {
        var icons: [EntityID: String] = [:]
        for id in snapshot.roadDisconnectedBuildings {
            icons[id] = "status-no-road"
        }
        for (id, population) in snapshot.housePopulations where !population.shortGoods.isEmpty {
            if let good = Good.allCases.first(where: population.isShort) { icons[id] = short(good) }
        }
        for (id, issue) in snapshot.buildingIssues {
            icons[id] = textureName(for: issue)
        }
        return icons.filter { snapshot.buildings[$0.key]?.owner == .player }
    }

    /// Node scale that keeps the on-screen size at `clamp(zoom)` of its zoom-1 size.
    static func scale(zoom: Double) -> CGFloat {
        let zoom = CGFloat(zoom)
        guard zoom > 0 else { return 1 }
        return min(max(zoom, zoomRange.lowerBound), zoomRange.upperBound) / zoom
    }

    /// A 2 pt bob over 1.8 s, started part-way through by the building's id so a street of icons
    /// does not move in step.
    static func bob(for id: EntityID) -> SKAction {
        let half = SKAction.moveBy(x: 0, y: 2, duration: 0.9)
        half.timingMode = .easeInEaseOut
        let phase = Double(UInt64(id.raw) &* 0x9E37_79B9 % 18) / 10
        return .sequence([.wait(forDuration: phase), .repeatForever(.sequence([half, half.reversed()]))])
    }

    static func make(named name: String, on sprite: SKSpriteNode, id: EntityID, zoom: Double, reduceMotion: Bool) -> SKSpriteNode {
        let side = discPoints / discFraction
        let icon = SKSpriteNode(texture: SpriteAtlas.textureOrPlaceholder(named: name), size: CGSize(width: side, height: side))
        icon.name = nodeName
        icon.userData = [IsoWorldScene.textureNameKey: name]
        icon.anchorPoint = CGPoint(x: 0.5, y: 0)
        icon.position = CGPoint(x: 0, y: sprite.size.height + lift)
        icon.zPosition = 100 // over the night shade (95), like the construction badge
        icon.setScale(scale(zoom: zoom))
        icon.alpha = 0
        icon.run(.fadeIn(withDuration: 0.2))
        if !reduceMotion { icon.run(bob(for: id), withKey: bobKey) }
        return icon
    }
}

extension IsoWorldScene {
    /// Adds, retextures and removes the status icons of the buildings on screen. One node per
    /// building at most; a node is only touched when its icon, the zoom or Reduce Motion changes.
    func reconcileStatusIcons(with snapshot: WorldSnapshot) {
        let wanted = StatusIcons.icons(in: snapshot)
        let scale = StatusIcons.scale(zoom: snapshot.camera.zoom)
        for (id, icon) in statusIcons {
            let sprite = snapshot.buildings[id].flatMap { buildingNodes[$0.anchor] }
            if wanted[id] == nil || sprite == nil || icon.parent !== sprite {
                icon.removeFromParent()
                statusIcons.removeValue(forKey: id)
            }
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
            if icon.xScale != scale { icon.setScale(scale) }
            let bobbing = icon.action(forKey: StatusIcons.bobKey) != nil
            if reduceMotion, bobbing {
                icon.removeAction(forKey: StatusIcons.bobKey)
                icon.position = CGPoint(x: 0, y: sprite.size.height + StatusIcons.lift)
            } else if !reduceMotion, !bobbing {
                icon.run(StatusIcons.bob(for: id), withKey: StatusIcons.bobKey)
            }
        }
    }

    /// The anchor of the building whose status icon covers `sceneLocation`, with the hit area
    /// grown to 44 on-screen points.
    func statusIconTile(at sceneLocation: CGPoint) -> TileCoordinate? {
        guard let snapshot = dataSource?.currentSnapshot() else { return nil }
        let screenPerLocal = CGFloat(snapshot.camera.zoom)
        for (id, icon) in statusIcons {
            guard let building = snapshot.buildings[id], icon.scene === self else { continue }
            let point = convert(sceneLocation, to: icon)
            // In the icon's own (unscaled) units; `size` already includes its scale.
            let side = icon.size.width / icon.xScale
            let reach = max(side, StatusIcons.hitPoints / (screenPerLocal * icon.xScale)) / 2
            if abs(point.x) <= reach, abs(point.y - side / 2) <= reach {
                return building.anchor
            }
        }
        return nil
    }
}
