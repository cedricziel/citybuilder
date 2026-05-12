import CityCore
import CoreGraphics
import Foundation
import SpriteKit

// Node-factory helpers for `IsoWorldScene`. Split out so the main scene
// file stays under the project's 500-line lint ceiling. These methods
// only touch SpriteKit / CoreGraphics; they read no scene state.

extension IsoWorldScene {
    func makeNode(for spec: SpriteSpec) -> SKNode {
        switch spec.kind {
        case let .terrain(kind):
            makeTerrainNode(kind: kind)
        case let .building(kind, state, footprint, frameIndex, orientation):
            makeBuildingNode(
                kind: kind,
                state: state,
                footprint: footprint,
                constructionFrameIndex: frameIndex,
                orientation: orientation
            )
        }
    }

    func makeTerrainNode(kind: TerrainType) -> SKNode {
        // The placeholder path satisfies the rendering-2_5d
        // `Missing-sprite fallback in release` requirement: if the
        // catalogued PNG is missing, a magenta 32×32 sprite renders
        // in its place and the miss is logged once per process.
        let texture = SpriteAtlas.textureOrPlaceholder(named: "terrain-\(kind.rawValue)")
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
    func makeBuildingNode(
        kind: BuildingKind,
        state: BuildingState,
        footprint: Footprint,
        constructionFrameIndex: Int?,
        orientation: ShoreOrientation?
    ) -> SKNode {
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
                constructionFrameIndex: constructionFrameIndex
            ) ?? SpriteAtlas.textureOrPlaceholder(named: "building-\(kind.rawValue)")
        }
        let node = buildingSpriteNode(
            texture: texture,
            state: state,
            footprint: footprint
        )
        armOperationalAnimationIfNeeded(on: node, kind: kind, state: state)
        return node
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
        constructionFrameIndex: Int?
    ) -> SKTexture? {
        switch state {
        case .constructing:
            return constructingTexture(kind: kind, frameIndex: constructionFrameIndex)
                ?? SpriteAtlas.buildingTexture(for: kind)
        case .operational:
            return SpriteAtlas.frames(for: .buildingOperational(kind))?.first
                ?? SpriteAtlas.buildingTexture(for: kind)
        case .planned:
            return SpriteAtlas.buildingTexture(for: kind)
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
        let offsetY = -halfH * (2 * footprintH - 1)
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
