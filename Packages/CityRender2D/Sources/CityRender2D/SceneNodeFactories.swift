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

    func makeNode(for spec: SpriteSpec) -> SKNode {
        switch spec.kind {
        case let .terrain(kind):
            makeTerrainNode(kind: kind, coord: spec.coord)
        case .building:
            makeBuildingNode(for: spec)
        }
    }

    func makeTerrainNode(kind: TerrainType, coord: TileCoordinate) -> SKNode {
        // Variant-aware lookup picks a deterministic per-tile sprite for
        // kinds with multiple variants (mountain); falls through to the
        // canonical sprite for all others. Placeholder path satisfies the
        // rendering-2_5d `Missing-sprite fallback in release` requirement.
        let texture = SpriteAtlas.terrainTextureOrPlaceholder(for: kind, coord: coord)
        let node = SKSpriteNode(texture: texture)
        node.zPosition = 0
        if let action = SpriteAnimation.loopingAction(for: .terrain(kind)) {
            node.run(action, withKey: "anim")
        }
        return node
    }

    /// Draw a building with its pre-rendered isometric pixel-art sprite.
    /// Geometry — sprite anchor (0.5, 0) sits at the anchor tile; the
    /// sprite's bottom diamond aligns with the actual iso footprint.
    /// See the design doc for the offset derivation.
    public func makeBuildingNode(for spec: SpriteSpec) -> SKNode {
        guard case let .building(
            kind, state, footprint, constructionFrameIndex, orientation, isWaitingForMaterials, isRoadDisconnected
        ) = spec.kind
        else {
            preconditionFailure("makeBuildingNode called with non-building spec kind")
        }
        let coord = spec.coord
        let texture: SKTexture
        if let orientation {
            // Shore buildings live under the `building-<kind>-<orientation>-*`
            // grammar; resolve the right state-keyed name and skip the
            // non-orientation fallback (which would magenta out).
            let name = ShoreOrientationMath.textureName(
                kind: kind,
                orientation: orientation,
                state: state,
                frame: state == .constructing ? (constructionFrameIndex ?? 0) : 0
            )
            texture = SpriteAtlas.textureOrPlaceholder(named: name)
        } else {
            texture = textureForBuilding(
                kind: kind,
                state: state,
                constructionFrameIndex: constructionFrameIndex,
                coord: coord
            ) ?? SpriteAtlas.buildingTextureOrPlaceholder(for: kind, coord: coord)
        }
        let node = buildingSpriteNode(
            texture: texture,
            state: state,
            footprint: footprint
        )
        armOperationalAnimationIfNeeded(on: node, kind: kind, state: state)
        if isWaitingForMaterials, state == .constructing {
            node.addChild(makeWaitingBadgeNode())
        }
        if isRoadDisconnected {
            node.addChild(makeNoRoadBadgeNode(spriteHeight: node.size.height))
        }
        return node
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

    private func armOperationalAnimationIfNeeded(
        on node: SKSpriteNode,
        kind: BuildingKind,
        state: BuildingState
    ) {
        guard state == .operational else { return }
        guard let action = SpriteAnimation.loopingAction(for: .buildingOperational(kind)) else {
            return
        }
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
        node.zPosition = 10 + footprintH
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
