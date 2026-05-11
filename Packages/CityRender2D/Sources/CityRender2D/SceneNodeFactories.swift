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
        case let .building(kind, state, footprint, frameIndex):
            makeBuildingNode(
                kind: kind,
                state: state,
                footprint: footprint,
                constructionFrameIndex: frameIndex
            )
        }
    }

    func makeTerrainNode(kind: TerrainType) -> SKNode {
        if let texture = SpriteAtlas.terrainTexture(for: kind) {
            let node = SKSpriteNode(texture: texture)
            node.zPosition = 0
            if let action = SpriteAnimation.loopingAction(for: .terrain(kind)) {
                node.run(action, withKey: "anim")
            }
            return node
        }
        let node = SKShapeNode(path: makeDiamondPath())
        node.fillColor = TerrainPalette.color(for: kind)
        node.strokeColor = SKColor.black.withAlphaComponent(0.15)
        node.lineWidth = 0.5
        node.zPosition = 0
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
        constructionFrameIndex: Int?
    ) -> SKNode {
        let initialTexture = textureForBuilding(
            kind: kind,
            state: state,
            constructionFrameIndex: constructionFrameIndex
        )
        if let texture = initialTexture {
            let node = buildingSpriteNode(
                texture: texture,
                state: state,
                footprint: footprint
            )
            armOperationalAnimationIfNeeded(on: node, kind: kind, state: state)
            return node
        }
        return buildingFallbackNode(kind: kind, state: state, footprint: footprint)
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

    private func buildingFallbackNode(
        kind: BuildingKind,
        state: BuildingState,
        footprint: Footprint
    ) -> SKNode {
        let path = makeBuildingDiamondPath(footprint: footprint)
        let node = SKShapeNode(path: path)
        node.fillColor = BuildingPalette.color(for: kind)
        if state == .constructing {
            node.fillColor = node.fillColor.withAlphaComponent(0.55)
        }
        node.strokeColor = SKColor.black.withAlphaComponent(0.5)
        node.lineWidth = 1.0
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

    func makeBuildingDiamondPath(footprint: Footprint) -> CGPath {
        let halfWidth = IsoMath.tileWidth / 2
        let halfHeight = IsoMath.tileHeight / 2
        let dx = CGFloat(footprint.width)
        let dy = CGFloat(footprint.height)
        let top = CGPoint(x: 0, y: halfHeight)
        let right = CGPoint(x: dx * halfWidth, y: -dx * halfHeight + halfHeight)
        let bottom = CGPoint(x: (dx - dy) * halfWidth, y: -(dx + dy) * halfHeight + halfHeight)
        let left = CGPoint(x: -dy * halfWidth, y: -dy * halfHeight + halfHeight)
        let path = CGMutablePath()
        path.move(to: top)
        path.addLine(to: right)
        path.addLine(to: bottom)
        path.addLine(to: left)
        path.closeSubpath()
        return path
    }

    func makeDiamondPath() -> CGPath {
        let halfWidth = IsoMath.tileWidth / 2
        let halfHeight = IsoMath.tileHeight / 2
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: halfHeight))
        path.addLine(to: CGPoint(x: halfWidth, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -halfHeight))
        path.addLine(to: CGPoint(x: -halfWidth, y: 0))
        path.closeSubpath()
        return path
    }
}

public enum TerrainPalette {
    public static func color(for kind: TerrainType) -> SKColor {
        switch kind {
        case .grass: SKColor(red: 0.42, green: 0.62, blue: 0.32, alpha: 1)
        case .forest: SKColor(red: 0.20, green: 0.42, blue: 0.20, alpha: 1)
        case .beach: SKColor(red: 0.90, green: 0.82, blue: 0.55, alpha: 1)
        case .water: SKColor(red: 0.18, green: 0.32, blue: 0.55, alpha: 1)
        case .mountain: SKColor(red: 0.40, green: 0.40, blue: 0.42, alpha: 1)
        }
    }
}

public enum BuildingPalette {
    public static func color(for kind: BuildingKind) -> SKColor {
        switch kind {
        case .house: SKColor(red: 0.78, green: 0.55, blue: 0.32, alpha: 1)
        case .warehouse: SKColor(red: 0.55, green: 0.45, blue: 0.35, alpha: 1)
        case .road: SKColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1)
        case .lumberjackHut: SKColor(red: 0.45, green: 0.30, blue: 0.18, alpha: 1)
        case .sawmill: SKColor(red: 0.65, green: 0.45, blue: 0.22, alpha: 1)
        case .townCenter: SKColor(red: 0.85, green: 0.60, blue: 0.25, alpha: 1)
        }
    }
}
