import CityCore
import CoreGraphics
import Foundation
import SpriteKit

// Node-factory helpers for `IsoWorldScene`. Split out so the main scene
// file stays under the project's 500-line lint ceiling. These methods
// only touch SpriteKit / CoreGraphics; they read no scene state.

extension IsoWorldScene {
    /// Name applied to the waiting-for-materials overlay child node.
    /// Tests use it to assert the badge attaches at the right moment.
    public static let waitingBadgeNodeName = "overlay-waiting-materials"
    /// Name applied to the no-road-access marker child node.
    public static let noRoadBadgeNodeName = "overlay-no-road"
    /// Name of a terrain object (tree clump) child node.
    public static let terrainObjectNodeName = "terrain-object"
    /// `userData` key holding the texture name chosen for a tiered house.
    public static let textureNameKey = "textureName"

    /// A node for `spec`, positioned in the scene: the factory's local
    /// offset (a building's footprint offset) is added to the anchor
    /// tile's screen point, and buildings are depth-sorted by the
    /// iso depth of their footprint centre so nearer ones draw on top.
    /// A building's z for its iso depth (anchor x + y plus half its
    /// footprint), so nearer buildings draw on top.
    static func depthZ(_ depth: Double) -> CGFloat {
        10 + CGFloat(depth) * 0.01
    }

    /// Lifts a figure just above a building at exactly its depth, and no further: a larger lift drew a
    /// figure still behind a building's corner over its roof.
    static let figureLift: CGFloat = 0.0001

    /// The z of a figure whose feet stand at `point`: its iso depth there (fractional column plus row,
    /// a tile centre counting as `x + y + 1` like a building's footprint centre), so a figure behind a
    /// building, or stepping out from behind it, stays hidden until it is level with or in front of it.
    static func figureZ(at point: CGPoint) -> CGFloat {
        let tile = IsoMath.tileCoordinate(forScreenPoint: point)
        return depthZ(tile.col + tile.row) + figureLift
    }

    /// Sinks a terrain object just behind the building at its depth: below a building level with it,
    /// above everything half a depth step behind (0.005), and a figure goes in front only once its feet
    /// are all but level with the clump, not 0.3 of a step early.
    static let objectSink: CGFloat = 0.0002

    /// Orders objects at one depth by column, inside the sink, so two overlapping neighbours (a crag
    /// beside a clump) never swap when the scene rebuilds. Objects that overlap at one depth are at
    /// most two columns apart, so three slots tell them apart, each wide enough to survive Float32 on
    /// the largest map, and the last still behind a building level with them.
    static let objectColumnStep: CGFloat = 0.00005

    /// The global z of a terrain object on `coord`.
    static func objectZ(at coord: TileCoordinate) -> CGFloat {
        depthZ(Double(coord.x + coord.y + 1)) - objectSink + CGFloat(coord.x % 3) * objectColumnStep
    }

    /// Flat ground buildings (roads, and the plaza that paves the town center's ring) lie on the ground:
    /// above the terrain and its shading (z 0–1), below everything that stands up. Figures and buildings
    /// sort only against each other, so a walker on a road never sinks into the tile it steps onto.
    static let flatGroundZ: CGFloat = 2

    static func liesFlat(_ kind: BuildingKind) -> Bool {
        kind == .road
    }

    func placedNode(for spec: SpriteSpec) -> SKNode {
        let node = makeNode(for: spec)
        let tile = IsoMath.screenPoint(forTile: spec.coord)
        node.position = CGPoint(x: tile.x + node.position.x, y: tile.y + node.position.y)
        if case let .building(kind, _, footprint, _, _, _, _, _, _, _) = spec.kind {
            let depth = Double(spec.coord.x + spec.coord.y) + Double(footprint.width + footprint.height) / 2
            node.zPosition = Self.liesFlat(kind) ? Self.flatGroundZ : Self.depthZ(depth)
        }
        return node
    }

    func makeNode(for spec: SpriteSpec) -> SKNode {
        switch spec.kind {
        case let .terrain(kind, transition, object):
            makeTerrainNode(kind: kind, coord: spec.coord, transition: transition, object: object)
        case .building:
            makeBuildingNode(for: spec)
        }
    }

    func makeTerrainNode(
        kind: TerrainType, coord: TileCoordinate, transition: TerrainTransition? = nil, object: TerrainObject? = nil
    ) -> SKNode {
        let objectName = object.flatMap { object in [object.assetName(in: appliedSeason), object.assetName].first(where: hasSprite) }
        // Forest and rock stand on grass, built on or not (terrain-v2, design D3).
        let floor: TerrainType = TerrainObject.kinds.contains(kind) ? .grass : kind
        let ground = makeGroundNode(kind: floor, coord: coord, transition: transition)
        if let objectName {
            let clump = makeObjectNode(named: objectName, coord: coord)
            if object?.kind == .forest {
                TreeSway.arm(clump, coord: coord, state: treeSwayState)
            }
            ground.addChild(clump)
        }
        return ground
    }

    /// A tree clump or rock outcrop over its tile: a 144 x 132 pt cell with the tile centre 56 pt
    /// from its left and 112 pt from its top, sorted like a 1 x 1 building on the tile, just behind
    /// any building at the same depth, and ordered by column against objects at that depth, so no
    /// tie flips (terrain-v2, design D4). The ground node sits at z 0, and a child's z adds to its
    /// parent's.
    private func makeObjectNode(named name: String, coord: TileCoordinate) -> SKSpriteNode {
        let node = SKSpriteNode(texture: SpriteAtlas.textureOrPlaceholder(named: name))
        node.name = Self.terrainObjectNodeName
        node.userData = [Self.textureNameKey: name]
        node.anchorPoint = CGPoint(x: 56.0 / 144.0, y: 20.0 / 132.0)
        node.zPosition = Self.objectZ(at: coord)
        return node
    }

    private func makeGroundNode(kind: TerrainType, coord: TileCoordinate, transition: TerrainTransition?) -> SKSpriteNode {
        // Blended shore and grass edges, once the terrain family ships its transition tiles; until
        // then (or for a missing mask) the tile keeps its own sprite. Shore shape outranks seasonal
        // tint, so the transition comes first.
        let transitionNames = transition.map { [$0.assetName(in: appliedSeason), $0.assetName] } ?? []
        if let name = transitionNames.first(where: hasSprite) {
            let node = SKSpriteNode(texture: SpriteAtlas.textureOrPlaceholder(named: name))
            node.userData = [Self.textureNameKey: name]
            node.zPosition = 0
            return node
        }
        // The season's look, in the tile's variant; a missing sprite draws the placeholder
        // (rendering-2_5d `Missing-sprite fallback in release`).
        let node = plainTerrainNode(kind: kind, coord: coord)
        node.zPosition = 0
        return node
    }

    /// Draw a building with its pre-rendered isometric pixel-art sprite.
    /// Geometry — sprite anchor (0.5, 0) sits at the anchor tile; the
    /// sprite's bottom diamond aligns with the actual iso footprint.
    /// See the design doc for the offset derivation.
    public func makeBuildingNode(for spec: SpriteSpec) -> SKNode {
        guard case let .building(
            kind, state, footprint, constructionFrameIndex, orientation,
            isWaitingForMaterials, isRoadDisconnected, houseTier, look, roadLink
        ) = spec.kind
        else {
            preconditionFailure("makeBuildingNode called with non-building spec kind")
        }
        let coord = spec.coord
        let texture: SKTexture
        var textureName: String?
        // The stem of a look with its own operational frames: a culture variant or a shore facing.
        var animationBase: String?
        let signature = Self.signatureTexture(kind: kind, look: look)
        if let (name, signatureTexture) = signature {
            textureName = name
            texture = signatureTexture
        } else if let (name, cultureTexture) = cultureTexture(
            kind: kind, state: state, houseTier: houseTier, rival: look.rival
        ) {
            textureName = name
            animationBase = name
            texture = cultureTexture
        } else if kind == .house, houseTier != .peasants, state != .constructing {
            // Spec: `rendering-2_5d` / Houses render their tier.
            let name = "building-house-tier\(houseTier.rawValue)"
            textureName = name
            texture = SpriteAtlas.textureOrPlaceholder(named: name)
        } else if let roadLink, hasSprite(roadLink.assetName) {
            // Spec: `rendering-2_5d` / Roads join their neighbours.
            textureName = roadLink.assetName
            texture = SpriteAtlas.textureOrPlaceholder(named: roadLink.assetName)
        } else if let orientation {
            (texture, animationBase) = shoreLook(
                kind: kind,
                orientation: orientation,
                state: state,
                constructionFrame: constructionFrameIndex
            )
        } else {
            texture = textureForBuilding(
                kind: kind,
                state: state,
                constructionFrameIndex: constructionFrameIndex,
                coord: coord
            ) ?? SpriteAtlas.buildingTextureOrPlaceholder(for: kind, coord: coord)
        }
        let node = buildingSpriteNode(texture: texture, state: state, footprint: footprint)
        if let textureName {
            node.userData = [Self.textureNameKey: textureName]
        }
        applyLook(look, to: node)
        addPennant(for: look, kind: kind, to: node)
        if signature == nil {
            armAnimation(on: node, kind: kind, state: state, animationBase: animationBase)
        }
        if isWaitingForMaterials, state == .constructing {
            node.addChild(makeWaitingBadgeNode())
        }
        if isRoadDisconnected {
            node.addChild(makeNoRoadBadgeNode(spriteHeight: node.size.height))
        }
        return node
    }

    /// A shore building's texture and the stem its operational frames hang off. Shore buildings
    /// live under the `building-<kind>-<orientation>-*` grammar; resolve the right state-keyed name
    /// and skip the non-orientation fallback (which would magenta out).
    private func shoreLook(
        kind: BuildingKind, orientation: ShoreOrientation, state: BuildingState, constructionFrame: Int?
    ) -> (SKTexture, String) {
        let name = ShoreOrientationMath.textureName(
            kind: kind,
            orientation: orientation,
            state: state,
            frame: state == .constructing ? (constructionFrame ?? 0) : 0
        )
        let stem = ShoreOrientationMath.textureName(kind: kind, orientation: orientation, state: nil, frame: nil)
        return (SpriteAtlas.textureOrPlaceholder(named: name), stem)
    }

    /// Red disc with a white bar floating over a building that no road
    /// touches. Drawn in code so it needs no atlas texture. Spec:
    /// `rendering-2_5d` / Road-access marker.
    private func makeNoRoadBadgeNode(spriteHeight: CGFloat) -> SKNode {
        let badge = SKShapeNode(circleOfRadius: 7)
        badge.name = Self.noRoadBadgeNodeName
        badge.fillColor = SKColor(red: 0.85, green: 0.15, blue: 0.12, alpha: 1)
        badge.strokeColor = SKColor(red: 0.10, green: 0.08, blue: 0.06, alpha: 1)
        badge.lineWidth = 1.5
        let bar = SKShapeNode(rectOf: CGSize(width: 8, height: 2.5))
        bar.fillColor = .white
        bar.strokeColor = .clear
        badge.addChild(bar)
        badge.position = CGPoint(x: 0, y: spriteHeight + 6)
        badge.zPosition = 100
        badge.run(.repeatForever(.sequence([.fadeAlpha(to: 0.55, duration: 0.6), .fadeAlpha(to: 1, duration: 0.6)])))
        return badge
    }

    /// Top-right clock-face overlay rendered while a constructing
    /// building waits for materials. Spec:
    /// `add-construction-stalls` / `rendering-2_5d` Requirement:
    /// Waiting-for-materials badge.
    private func makeWaitingBadgeNode() -> SKSpriteNode {
        let texture = SpriteAtlas.textureOrPlaceholder(named: "overlay-waiting-materials")
        let badge = SKSpriteNode(texture: texture)
        badge.name = Self.waitingBadgeNodeName
        badge.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        // Float the badge above the building base. The exact placement
        // depends on building footprint; centering above the anchor
        // gives a reasonable default while keeping the badge readable.
        badge.position = CGPoint(x: IsoMath.tileWidth / 2, y: IsoMath.tileHeight * 2)
        badge.zPosition = 100
        return badge
    }

    /// The idle sprite of a signature building that is off, or the
    /// construction frame of an unfinished monument; nil otherwise.
    static func signatureTexture(kind: BuildingKind, look: BuildingLook) -> (String, SKTexture)? {
        if let frame = look.projectFrame {
            let name = SpriteAnimation.assetName(for: .buildingConstructing(kind), frame: frame)
            return (name, SpriteAtlas.textureOrPlaceholder(named: name))
        }
        guard look.idle else { return nil }
        let name = "building-\(kind.rawValue)"
        return (name, SpriteAtlas.textureOrPlaceholder(named: name))
    }

    /// Smoky houses are tinted grey (design D9).
    private func applyLook(_ look: BuildingLook, to node: SKSpriteNode) {
        guard look.smoky else { return }
        node.color = SKColor(white: 0.5, alpha: 1)
        node.colorBlendFactor = 0.25
    }

    /// Every rival building but a road flies its rival's pennant.
    private func addPennant(for look: BuildingLook, kind: BuildingKind, to node: SKSpriteNode) {
        guard let rival = look.rival, kind != .road else { return }
        node.addChild(Self.makePennantNode(colourHex: rival.colour.hex, on: node, footprint: BuildingCatalog.spec(for: kind).footprint))
    }

    /// Loops an operational building's frames: its own look's, else the kind's shared ones.
    private func armAnimation(on node: SKSpriteNode, kind: BuildingKind, state: BuildingState, animationBase: String?) {
        guard state == .operational,
              let action = SpriteAnimation.loopingAction(for: .buildingOperational(kind, stem: animationBase))
        else { return }
        node.run(action, withKey: "anim")
    }

    private func textureForBuilding(
        kind: BuildingKind,
        state: BuildingState,
        constructionFrameIndex: Int?,
        coord: TileCoordinate
    ) -> SKTexture? {
        // Variant lookup applies only to states that show the canonical
        // idle/operational sprite. Constructing/operational frames keep
        // the existing single-PNG paths so animation timing stays put.
        switch state {
        case .constructing:
            return constructingTexture(kind: kind, frameIndex: constructionFrameIndex)
                ?? SpriteAtlas.buildingTextureOrPlaceholder(for: kind, coord: coord)
        case .operational:
            return SpriteAtlas.frames(for: .buildingOperational(kind))?.first
                ?? SpriteAtlas.buildingTextureOrPlaceholder(for: kind, coord: coord)
        case .planned:
            return SpriteAtlas.buildingTextureOrPlaceholder(for: kind, coord: coord)
        }
    }

    private func buildingSpriteNode(
        texture: SKTexture,
        state: BuildingState,
        footprint: Footprint
    ) -> SKSpriteNode {
        let node = SKSpriteNode(texture: texture)
        node.anchorPoint = CGPoint(x: 0.5, y: 0)
        let halfH = IsoMath.tileHeight / 2
        let footprintH = CGFloat(footprint.height)
        let footprintW = CGFloat(footprint.width)
        // Bottom-centre of the sprite sits on the footprint's bottom vertex.
        let offsetY = -halfH * (footprintW + footprintH - 1)
        let offsetX = (footprintW - footprintH) * IsoMath.tileWidth / 4
        node.position = CGPoint(x: offsetX, y: offsetY)
        if state == .constructing { node.alpha = 0.85 }
        node.zPosition = 10
        return node
    }

    private func constructingTexture(kind: BuildingKind, frameIndex: Int?) -> SKTexture? {
        guard let frames = SpriteAtlas.frames(for: .buildingConstructing(kind)),
              !frames.isEmpty
        else { return nil }
        let idx = max(0, min(frameIndex ?? 0, frames.count - 1))
        return frames[idx]
    }
}
