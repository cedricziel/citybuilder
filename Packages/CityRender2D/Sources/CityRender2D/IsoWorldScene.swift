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
    /// Season whose terrain tint is on screen. Spec: `rendering-2_5d` /
    /// Terrain shows the season.
    var appliedSeason: Season = .spring
    /// Culture whose building looks are on screen. Spec: `rendering-2_5d`
    /// / Buildings render in the world's culture.
    public var culture: Culture = .northernEuropean
    /// Age whose house looks are on screen. Spec: `rendering-2_5d` /
    /// Houses render in the world's age.
    public var age: Age = .medieval
    /// Whether the atlas holds a sprite. Optional looks (culture and
    /// seasonal variants) check it before falling back; tests replace it
    /// because SwiftPM test bundles carry no atlases.
    var hasSprite: (String) -> Bool = { SpriteAtlas.texture(named: $0) != nil }
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

    /// Camera-driven listener push for the audio layer's spatial graph.
    /// Per spec `rendering-2_5d` "Camera listener callback" — called at
    /// most once per wall-clock second with the camera's current
    /// `centerTile()`. App shells set this to `audio.setListenerPosition`.
    public var cameraListener: ((TileCoordinate) -> Void)?

    /// Last wall-clock time (in SpriteKit's `update` clock) the listener
    /// callback fired. `-Double.infinity` means it has never fired, so the
    /// first tick after `cameraListener` is set produces an immediate push.
    private var lastListenerPushAt: TimeInterval = -.infinity

    /// Throttle interval for the listener push, in seconds. Matches
    /// spec `audio-playback` design D3 — 1 Hz keeps the AVAudioEngine
    /// listener from jittering on sub-tile camera oscillations.
    public static let listenerPushInterval: TimeInterval = 1.0

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
        handlePointerReleased(at: touch.location(in: self))
    }

    override public func touchesMoved(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard let touch = touches.first else { return }
        handlePointerMoved(to: touch.location(in: self))
    }

    override public func touchesCancelled(_: Set<UITouch>, with _: UIEvent?) {
        lastDragTile = nil
    }

    #elseif canImport(AppKit)
    override public func mouseUp(with event: NSEvent) {
        handlePointerReleased(at: event.location(in: self))
    }

    override public func mouseDragged(with event: NSEvent) {
        handlePointerMoved(to: event.location(in: self))
    }

    override public func mouseMoved(with event: NSEvent) {
        let location = event.location(in: self)
        dispatchHover(at: location)
    }

    override public func mouseExited(with _: NSEvent) {
        intentSink?(.hoverTile(nil))
    }
    #endif

    /// Finger / mouse moved while down: paint the tile under it.
    func handlePointerMoved(to sceneLocation: CGPoint) {
        dispatchDrag(at: sceneLocation)
    }

    /// Finger / mouse released. A release that ends a drag sends no
    /// tap: the drag already painted the last tile, and a tap there
    /// would be rejected as occupied.
    func handlePointerReleased(at sceneLocation: CGPoint) {
        if lastDragTile == nil {
            dispatchTap(at: sceneLocation)
        }
        lastDragTile = nil
    }

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
        for tile in Self.orthogonalSteps(from: lastDragTile, to: coord) {
            intentSink?(.dragTile(tile))
        }
        lastDragTile = coord
    }

    /// Tiles to paint when the finger moves from `from` to `to`: every
    /// tile on a 4-connected path, so a fast or diagonal drag never
    /// leaves a corner-only gap in a road. Steps along x first.
    static func orthogonalSteps(from: TileCoordinate?, to: TileCoordinate) -> [TileCoordinate] {
        guard var current = from else { return [to] }
        var steps: [TileCoordinate] = []
        while current != to {
            if current.x != to.x {
                current = TileCoordinate(x: current.x + (to.x > current.x ? 1 : -1), y: current.y)
            } else {
                current = TileCoordinate(x: current.x, y: current.y + (to.y > current.y ? 1 : -1))
            }
            steps.append(current)
        }
        return steps
    }

    private func dispatchHover(at sceneLocation: CGPoint) {
        guard let snapshot = dataSource?.currentSnapshot() else { return }
        let coord = tile(forScene: sceneLocation, mapWidth: snapshot.mapWidth, mapHeight: snapshot.mapHeight)
        intentSink?(.hoverTile(coord))
    }

    override public func update(_ currentTime: TimeInterval) {
        guard let snapshot = dataSource?.currentSnapshot() else { return }
        applyCamera(snapshot.camera)
        applySeason(snapshot.date.season)
        applyLook(culture: snapshot.culture, age: snapshot.age)
        reconcileSprites(with: snapshot)
        reconcileCarriers(with: snapshot)
        reconcileGhost()
        pushListenerIfDue(currentTime: currentTime, camera: snapshot.camera)
    }

    private func pushListenerIfDue(currentTime: TimeInterval, camera: Camera) {
        // Skip all per-second bookkeeping when no consumer is attached —
        // headless renderers and tests pay nothing for this path.
        guard let listener = cameraListener else { return }
        guard currentTime - lastListenerPushAt >= Self.listenerPushInterval else { return }
        lastListenerPushAt = currentTime
        listener(camera.centerTile())
    }

    private func reconcileGhost() {
        guard let ghost = ghostProvider?() else {
            ghostNode?.removeFromParent()
            ghostNode = nil
            return
        }
        // Variant-aware lookup so the ghost preview of a road tile shows
        // the same variant the placed tile will use.
        let texture = SpriteAtlas.buildingTextureOrPlaceholder(
            for: ghost.kind,
            coord: ghost.tile
        )
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
            y: tileScreen.y - halfH * (footprintW + footprintH - 1)
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

    /// Rebuilds every sprite when culture or age changes, so houses
    /// restyle in place.
    private func applyLook(culture newCulture: Culture, age newAge: Age) {
        guard newCulture != culture || newAge != age else { return }
        culture = newCulture
        age = newAge
        for node in presentSprites.values {
            node.removeFromParent()
        }
        presentSprites.removeAll()
    }

    /// Drops present vegetation nodes on a season change so the next
    /// reconcile rebuilds them with the season's sprites.
    private func applySeason(_ season: Season) {
        guard season != appliedSeason else { return }
        appliedSeason = season
        for (spec, node) in presentSprites {
            guard case let .terrain(kind) = spec.kind, Self.seasonalTerrain.contains(kind) else { continue }
            node.removeFromParent()
            presentSprites.removeValue(forKey: spec)
        }
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
            let node = placedNode(for: spec)
            addChild(node)
            presentSprites[spec] = node
        }
    }
}

@MainActor
public protocol IsoWorldDataSource: AnyObject {
    func currentSnapshot() -> WorldSnapshot?
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
        ghostProvider: (@MainActor @Sendable () -> IsoWorldScene.GhostState?)? = nil,
        cameraListener: (@MainActor @Sendable (TileCoordinate) -> Void)? = nil
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
        if let cameraListener {
            prepared.cameraListener = { tile in cameraListener(tile) }
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
