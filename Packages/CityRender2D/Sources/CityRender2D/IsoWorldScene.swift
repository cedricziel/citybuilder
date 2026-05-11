import CityCore
import CoreGraphics
import Foundation
import SpriteKit

#if canImport(SwiftUI)
import SwiftUI
#endif

/// Snapshot-driven SpriteKit scene. Holds no simulation state — every
/// frame it asks its `dataSource` for the current snapshot and reconciles
/// the scene tree against the desired sprite set.
public final class IsoWorldScene: SKScene {
    public var dataSource: IsoWorldDataSource?
    public var intentSink: ((Intent) -> Void)?

    /// Tracks which sprite specs are currently present in the scene tree so
    /// each frame can compute add/remove diffs via SnapshotReconciler.
    private var presentSprites: [SpriteSpec: SKNode] = [:]
    /// Carrier nodes keyed by carrier EntityID raw, with the last-known
    /// path index so we can interpolate movement.
    private struct CarrierVisual {
        var node: SKSpriteNode
        var lastPathIndex: Int
        var lastTickCount: UInt64
        var facing: SpriteAtlas.WalkerFacing
    }

    private var carrierVisuals: [UInt32: CarrierVisual] = [:]
    private let cameraNode = SKCameraNode()

    /// Ghost preview node shown at the hovered tile when a build tool is
    /// armed. The scene polls `ghostProvider` on every update; the
    /// controller (GameSession) returns the current ghost state.
    private var ghostNode: SKSpriteNode?
    public var ghostProvider: (() -> GhostState?)?

    public struct GhostState {
        public let kind: BuildingKind
        public let tile: TileCoordinate
        public let valid: Bool
        public init(kind: BuildingKind, tile: TileCoordinate, valid: Bool) {
            self.kind = kind; self.tile = tile; self.valid = valid
        }
    }

    /// Last tile reported by a drag movement so we don't spam dragTile
    /// intents for the same tile while the finger / pointer moves within it.
    private var lastDragTile: TileCoordinate?

    override public func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.05, green: 0.08, blue: 0.12, alpha: 1)
        scaleMode = .resizeFill
        addChild(cameraNode)
        camera = cameraNode
        #if canImport(AppKit)
        // mouseMoved only fires when the host window allows it; opt in here
        // so hover-driven ghost preview works on macOS.
        view.window?.acceptsMouseMovedEvents = true
        let trackingArea = NSTrackingArea(
            rect: view.bounds,
            options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited],
            owner: view,
            userInfo: nil
        )
        view.addTrackingArea(trackingArea)
        #endif
    }

    #if canImport(UIKit)
    override public func touchesEnded(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        dispatchTap(at: location)
        lastDragTile = nil
    }

    override public func touchesMoved(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        dispatchDrag(at: location)
    }

    override public func touchesCancelled(_: Set<UITouch>, with _: UIEvent?) {
        lastDragTile = nil
    }

    #elseif canImport(AppKit)
    override public func mouseUp(with event: NSEvent) {
        let location = event.location(in: self)
        dispatchTap(at: location)
        lastDragTile = nil
    }

    override public func mouseDragged(with event: NSEvent) {
        let location = event.location(in: self)
        dispatchDrag(at: location)
    }

    override public func mouseMoved(with event: NSEvent) {
        let location = event.location(in: self)
        dispatchHover(at: location)
    }

    override public func mouseExited(with _: NSEvent) {
        intentSink?(.hoverTile(nil))
    }
    #endif

    private func tile(forScene location: CGPoint, mapWidth: Int, mapHeight: Int) -> TileCoordinate? {
        let coord = IsoMath.nearestTile(toScreenPoint: location)
        guard coord.x >= 0, coord.x < mapWidth, coord.y >= 0, coord.y < mapHeight else {
            return nil
        }
        return coord
    }

    private func dispatchTap(at sceneLocation: CGPoint) {
        guard let snapshot = dataSource?.currentSnapshot(),
              let coord = tile(forScene: sceneLocation, mapWidth: snapshot.mapWidth, mapHeight: snapshot.mapHeight)
        else { return }
        intentSink?(.tapTile(coord))
    }

    private func dispatchDrag(at sceneLocation: CGPoint) {
        guard let snapshot = dataSource?.currentSnapshot(),
              let coord = tile(forScene: sceneLocation, mapWidth: snapshot.mapWidth, mapHeight: snapshot.mapHeight)
        else { return }
        guard coord != lastDragTile else { return }
        lastDragTile = coord
        intentSink?(.dragTile(coord))
    }

    private func dispatchHover(at sceneLocation: CGPoint) {
        guard let snapshot = dataSource?.currentSnapshot() else { return }
        let coord = tile(forScene: sceneLocation, mapWidth: snapshot.mapWidth, mapHeight: snapshot.mapHeight)
        intentSink?(.hoverTile(coord))
    }

    override public func update(_: TimeInterval) {
        guard let snapshot = dataSource?.currentSnapshot() else { return }
        applyCamera(snapshot.camera)
        reconcileSprites(with: snapshot)
        reconcileCarriers(with: snapshot)
        reconcileGhost()
    }

    private func reconcileGhost() {
        guard let ghost = ghostProvider?() else {
            ghostNode?.removeFromParent()
            ghostNode = nil
            return
        }
        guard let texture = SpriteAtlas.buildingTexture(for: ghost.kind) else {
            ghostNode?.removeFromParent()
            ghostNode = nil
            return
        }
        let node = ghostNode ?? SKSpriteNode(texture: texture)
        node.texture = texture
        node.anchorPoint = CGPoint(x: 0.5, y: 0)
        let halfH = IsoMath.tileHeight / 2
        let footprint = BuildingCatalog.spec(for: ghost.kind).footprint
        let footprintH = CGFloat(footprint.height)
        let footprintW = CGFloat(footprint.width)
        let tileScreen = IsoMath.screenPoint(forTile: ghost.tile)
        node.position = CGPoint(
            x: tileScreen.x + (footprintW - footprintH) * IsoMath.tileWidth / 4,
            y: tileScreen.y - halfH * (2 * footprintH - 1)
        )
        node.zPosition = 1000 // always on top
        node.alpha = 0.5
        node.color = ghost.valid
            ? SKColor(red: 0.4, green: 1.0, blue: 0.4, alpha: 1)
            : SKColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1)
        node.colorBlendFactor = 0.55
        if ghostNode == nil {
            ghostNode = node
            addChild(node)
        }
    }

    private func reconcileCarriers(with snapshot: WorldSnapshot) {
        let currentIDs = Set(snapshot.carriers.map(\.id.raw))
        // Despawn nodes for carriers that no longer exist.
        for staleID in carrierVisuals.keys where !currentIDs.contains(staleID) {
            carrierVisuals[staleID]?.node.removeFromParent()
            carrierVisuals.removeValue(forKey: staleID)
        }
        // Add / update nodes for each live carrier.
        for carrier in snapshot.carriers {
            let facing = walkerFacing(for: carrier)
            if var visual = carrierVisuals[carrier.id.raw] {
                // Update facing if it changed (new path segment direction).
                if visual.facing != facing {
                    if let frames = SpriteAtlas.walkerAnimation(facing: facing) {
                        visual.facing = facing
                        visual.node.removeAction(forKey: "walk")
                        visual.node.run(
                            SKAction.repeatForever(SKAction.animate(with: frames, timePerFrame: 0.15)),
                            withKey: "walk"
                        )
                    }
                }
                visual.lastPathIndex = carrier.pathIndex
                visual.lastTickCount = snapshot.tickCount
                visual.node.position = position(forCarrier: carrier)
                carrierVisuals[carrier.id.raw] = visual
            } else if let frames = SpriteAtlas.walkerAnimation(facing: facing) {
                let node = SKSpriteNode(texture: frames.first)
                node.anchorPoint = CGPoint(x: 0.5, y: 0)
                node.position = position(forCarrier: carrier)
                node.zPosition = 50 // above terrain, below tall buildings
                node.texture?.filteringMode = .nearest
                node.run(
                    SKAction.repeatForever(SKAction.animate(with: frames, timePerFrame: 0.15)),
                    withKey: "walk"
                )
                addChild(node)
                carrierVisuals[carrier.id.raw] = CarrierVisual(
                    node: node,
                    lastPathIndex: carrier.pathIndex,
                    lastTickCount: snapshot.tickCount,
                    facing: facing
                )
            }
        }
    }

    private func walkerFacing(for carrier: Carrier) -> SpriteAtlas.WalkerFacing {
        // Determine facing from the next path segment direction.
        let idx = carrier.pathIndex
        guard idx >= 0, idx < carrier.path.count - 1 else { return .se }
        let from = carrier.path[idx]
        let to = carrier.path[idx + 1]
        if to.x > from.x { return .se }
        if to.x < from.x { return .nw }
        if to.y > from.y { return .sw }
        return .ne
    }

    private func position(forCarrier carrier: Carrier) -> CGPoint {
        guard let current = carrier.currentTile else { return .zero }
        // Carrier sprite is drawn at the tile's iso position, slightly
        // above the tile center so the figure appears to stand on it.
        let basePoint = IsoMath.screenPoint(forTile: current)
        return CGPoint(x: basePoint.x, y: basePoint.y - IsoMath.tileHeight / 2)
    }

    private func applyCamera(_ stateCamera: Camera) {
        let center = IsoMath.screenPoint(
            forTileFractionalX: stateCamera.centerX,
            fractionalY: stateCamera.centerY
        )
        cameraNode.position = center
        let scale = CGFloat(1.0 / stateCamera.zoom)
        cameraNode.setScale(scale)
    }

    private func reconcileSprites(with snapshot: WorldSnapshot) {
        guard let (xRange, yRange) = Culling.visibleTileRange(
            camera: snapshot.camera,
            viewSize: size,
            mapWidth: snapshot.mapWidth,
            mapHeight: snapshot.mapHeight
        )
        else { return }

        let desired = SnapshotReconciler.desiredSprites(
            in: snapshot,
            xRange: xRange,
            yRange: yRange
        )
        let diff = SnapshotReconciler.diff(
            previous: Set(presentSprites.keys),
            current: desired
        )
        for spec in diff.removed {
            presentSprites.removeValue(forKey: spec)?.removeFromParent()
        }
        for spec in diff.added {
            let node = makeNode(for: spec)
            node.position = IsoMath.screenPoint(forTile: spec.coord)
            addChild(node)
            presentSprites[spec] = node
        }
    }

    private func makeNode(for spec: SpriteSpec) -> SKNode {
        switch spec.kind {
        case let .terrain(kind):
            return makeTerrainNode(kind: kind)
        case let .building(kind, state, footprint):
            return makeBuildingNode(kind: kind, state: state, footprint: footprint)
        }
    }

    private func makeTerrainNode(kind: TerrainType) -> SKNode {
        if let texture = SpriteAtlas.terrainTexture(for: kind) {
            let node = SKSpriteNode(texture: texture)
            node.zPosition = 0
            return node
        }
        // Fallback to the colored diamond when the sprite asset is missing
        // (e.g., in headless unit tests with no resource bundle).
        let node = SKShapeNode(path: makeDiamondPath())
        node.fillColor = TerrainPalette.color(for: kind)
        node.strokeColor = SKColor.black.withAlphaComponent(0.15)
        node.lineWidth = 0.5
        node.zPosition = 0
        return node
    }

    /// Draw a building with its pre-rendered isometric pixel-art sprite.
    /// The sprite contains its footprint diamond at the bottom; we place
    /// it so that diamond aligns with the actual iso footprint.
    ///
    /// Geometry:
    /// - Sprite anchor (0.5, 0) → bottom-center at the sprite's position.
    /// - The sprite's diamond center is `footprintH * tileH / 2` above the
    ///   anchor (the diamond is the bottom `footprintH * tileH` pixels).
    /// - The world footprint center sits `(footprintH - 1) * tileH / 2`
    ///   BELOW the anchor tile center (each extra tile adds halfH drop in
    ///   iso projection).
    /// - Therefore the sprite must be placed at:
    ///       y = -((footprintH - 1) * tileH / 2) - footprintH * tileH / 2
    ///         = -tileH * (2 * footprintH - 1) / 2
    /// - For 1x1: y = -tileH/2 (= -16). 2x2: -48. 3x3: -80.
    /// - Non-square footprints also need x = (footprintW - footprintH) * tileW / 4.
    private func makeBuildingNode(kind: BuildingKind, state: BuildingState, footprint: Footprint) -> SKNode {
        if let texture = SpriteAtlas.buildingTexture(for: kind) {
            let node = SKSpriteNode(texture: texture)
            node.anchorPoint = CGPoint(x: 0.5, y: 0)
            let halfH = IsoMath.tileHeight / 2
            let footprintH = CGFloat(footprint.height)
            let footprintW = CGFloat(footprint.width)
            let offsetY = -halfH * (2 * footprintH - 1)
            let offsetX = (footprintW - footprintH) * IsoMath.tileWidth / 4
            node.position = CGPoint(x: offsetX, y: offsetY)
            if state == .constructing { node.alpha = 0.55 }
            node.zPosition = 10 + footprintH // rear-to-front sort
            return node
        }
        // Fallback: colored parallelogram.
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

    /// Iso projection of a rectangular footprint anchored at (0,0) where
    /// (0,0) is the anchor tile in scene coordinates. The four corners
    /// project to a parallelogram which we connect with a closed path.
    private func makeBuildingDiamondPath(footprint: Footprint) -> CGPath {
        let halfWidth = IsoMath.tileWidth / 2
        let halfHeight = IsoMath.tileHeight / 2
        let dx = CGFloat(footprint.width)
        let dy = CGFloat(footprint.height)
        // Project the four corners of the footprint (col, row) into screen
        // space using the same formula as IsoMath.screenPoint(forTile:),
        // expressed relative to the anchor tile (0,0).
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

    private func makeDiamondPath() -> CGPath {
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

@MainActor
public protocol IsoWorldDataSource: AnyObject {
    func currentSnapshot() -> WorldSnapshot?
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

#if canImport(SwiftUI)
/// SwiftUI host for the snapshot-driven iso scene. App shells construct
/// this with a closure that yields the current snapshot.
@MainActor
public struct IsoWorldView: View {
    @State private var scene: IsoWorldScene

    public init(
        snapshotProvider: @escaping @MainActor @Sendable () -> WorldSnapshot?,
        intentSink: (@MainActor @Sendable (Intent) -> Void)? = nil,
        ghostProvider: (@MainActor @Sendable () -> IsoWorldScene.GhostState?)? = nil
    ) {
        let prepared = IsoWorldScene()
        prepared.size = CGSize(width: 1024, height: 768)
        prepared.scaleMode = .resizeFill
        let bridge = SnapshotProviderBridge(provider: snapshotProvider)
        prepared.dataSource = bridge
        if let intentSink {
            prepared.intentSink = { intent in
                Task { @MainActor in intentSink(intent) }
            }
        }
        if let ghostProvider {
            prepared.ghostProvider = { ghostProvider() }
        }
        // Retain the bridge by parking it on the scene.
        prepared.userData = ["__snapshotBridge": bridge]
        _scene = State(initialValue: prepared)
    }

    public var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
    }
}

@MainActor
private final class SnapshotProviderBridge: NSObject, IsoWorldDataSource {
    let provider: @MainActor @Sendable () -> WorldSnapshot?
    init(provider: @escaping @MainActor @Sendable () -> WorldSnapshot?) {
        self.provider = provider
    }

    func currentSnapshot() -> WorldSnapshot? {
        provider()
    }
}
#endif
