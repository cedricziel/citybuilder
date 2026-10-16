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
    var presentSprites: [SpriteSpec: SKNode] = [:]
    /// City life (`add-city-life`): night shade and strolling residents.
    let nightOverlay = SKSpriteNode()
    var strollerNodes: [StrollerKey: SKSpriteNode] = [:]
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
    /// Terrain transitions for the current map, rebuilt only when the terrain grid changes.
    private(set) var transitionMap: TerrainTransitionMap?
    /// What stands on each tile (trees), rebuilt only when terrain or occupancy changes.
    private(set) var objectMap: TerrainObjectMap?
    /// Road links, worked out again only when a building is placed or removed.
    private(set) var roadLinkCache = RoadLinkCache()
    /// The ground macro field, built again only when terrain, occupancy or the season's look changes.
    var groundMacroCache = GroundMacroCache()
    /// Whether a macro field is building off the main thread, and the latest request waiting for it.
    var groundMacroBuilding = false
    var groundMacroPending: GroundMacroInputs?
    /// What the macro field on screen was built from.
    var groundMacroShown: GroundMacroInputs?
    /// Carrier nodes keyed by carrier id. Spec: `rendering-2_5d` /
    /// Carriers glide and show their load.
    var carrierVisuals: [EntityID: CarrierVisual] = [:]
    var lastCarrierTick: UInt64?
    private let cameraNode = SKCameraNode()

    /// Ghost preview node shown at the hovered tile when a build tool is
    /// armed. The scene polls `ghostProvider` on every update; the
    /// controller (GameSession) returns the current ghost state.
    private var ghostNode: SKSpriteNode?
    public var ghostProvider: (() -> GhostState?)?
    /// Tile the inspector has selected; a selected signature building
    /// shows its range rings.
    public var selectionProvider: (() -> TileCoordinate?)?
    /// Range rings and highlights, keyed by the source they show.
    let signatureRingLayer = SKNode()
    var signatureRingSource: SignatureRingSource?
    /// The route to draw, polled every frame. Spec: `rendering-2_5d` /
    /// Route overlay from the session.
    public var routeOverlayProvider: (() -> RouteOverlay?)?
    let routeLayer = RouteLayerNode()
    let shipLayer = ShipLayerNode()
    /// Chimney smoke and steam. Spec: `rendering-2_5d` / Chimneys smoke.
    let ambientLayer = AmbientLayerNode()
    var lastAmbientPass: AmbientPass?
    var smokeSources: [SmokeSource] = []
    /// Building sprites on screen by anchor tile, kept with `presentSprites`.
    var buildingNodes: [TileCoordinate: SKSpriteNode] = [:]
    /// The `-lights` texture per sprite stem, or nil when the atlas has
    /// none. Spec: `rendering-2_5d` / Lit windows follow the lights art.
    var lightsNames: [String: String?] = [:]
    /// Hearth glows on screen, by building. Spec: `rendering-2_5d` / Fire
    /// trades glow at night.
    var fireGlows: [EntityID: SKNode] = [:]
    /// Residents on the town center plazas. Spec: `rendering-2_5d`
    /// / Residents gather on the plaza.
    var plazaNodes: [PlazaFigureKey: (node: SKSpriteNode, pose: PlazaPose)] = [:]
    var lastPlazaPass: PlazaPass?
    var plazaTickAt: TimeInterval = 0
    /// Halves ambient motion when on. `IsoWorldView` sets it from the
    /// Reduce Motion accessibility setting.
    public var reduceMotion = false
    var highlightedSignatureTargets: [EntityID] {
        signatureRingSource?.affected ?? []
    }

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
    var lastDragTile: TileCoordinate?

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
        installNightOverlay()
        #if os(iOS)
        installLongPressRecognizer(on: view)
        #elseif canImport(AppKit)
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

    #if os(iOS)
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

    override public func update(_ currentTime: TimeInterval) {
        guard let snapshot = dataSource?.currentSnapshot() else { return }
        applyCamera(snapshot.camera)
        applySeason(snapshot.date.season)
        reconcileGround(with: snapshot)
        applyLook(culture: snapshot.culture, age: snapshot.age)
        applyTimeOfDay(TimeOfDay(tick: snapshot.tickCount))
        reconcileSprites(with: snapshot)
        updateWindowGlow(with: snapshot)
        reconcileCarriers(with: snapshot, now: currentTime)
        reconcileRoutes(with: snapshot)
        reconcileShips(with: snapshot)
        reconcileStrollers(with: snapshot)
        reconcilePlazaCrowd(with: snapshot, now: currentTime)
        reconcileAmbient(with: snapshot)
        reconcileFireGlow(with: snapshot)
        reconcileGhost(with: snapshot)
        reconcileSignatureRings(with: snapshot)
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

    private func reconcileGhost(with snapshot: WorldSnapshot) {
        guard let ghost = ghostProvider?() else {
            ghostNode?.removeFromParent()
            ghostNode = nil
            return
        }
        // A shore building has no facing-free sprite: show the facing it would get there.
        let shore = ShoreOrientationMath.ghostTextureName(kind: ghost.kind, anchor: ghost.tile, terrain: snapshot.terrain(at:))
        let texture = shore.map(SpriteAtlas.textureOrPlaceholder(named:))
            ?? SpriteAtlas.buildingTextureOrPlaceholder(for: ghost.kind, coord: ghost.tile)
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
        buildingNodes.removeAll()
    }

    /// Drops present vegetation nodes, and the grass edges that blend them, on a
    /// season change so the next reconcile rebuilds them with the season's sprites.
    /// Seasons with the same look (spring and summer) redraw nothing.
    private func applySeason(_ season: Season) {
        guard season != appliedSeason else { return }
        let changesLook = Self.seasonalTerrain.contains {
            Self.seasonalTerrainName(kind: $0, season: season) != Self.seasonalTerrainName(kind: $0, season: appliedSeason)
        }
        appliedSeason = season
        guard changesLook else { return }
        for (spec, node) in presentSprites {
            guard case let .terrain(kind, transition, object) = spec.kind,
                  Self.seasonalTerrain.contains(kind) || transition?.upper == .grass || object != nil
            else { continue }
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

        if transitionMap?.matches(width: snapshot.mapWidth, height: snapshot.mapHeight, grid: snapshot.terrainGrid) != true {
            transitionMap = TerrainTransitionMap(width: snapshot.mapWidth, height: snapshot.mapHeight, grid: snapshot.terrainGrid)
        }
        if objectMap?.matches(
            width: snapshot.mapWidth,
            height: snapshot.mapHeight,
            grid: snapshot.terrainGrid,
            occupancy: snapshot.occupiedTiles
        ) != true {
            objectMap = TerrainObjectMap(
                width: snapshot.mapWidth, height: snapshot.mapHeight, grid: snapshot.terrainGrid, occupancy: snapshot.occupiedTiles
            )
        }
        let desired = SnapshotReconciler.desiredSprites(
            in: snapshot,
            xRange: xRange,
            yRange: yRange,
            transitions: transitionMap,
            roadLinks: roadLinkCache.links(for: snapshot),
            objects: objectMap
        )
        let diff = SnapshotReconciler.diff(
            previous: Set(presentSprites.keys),
            current: desired
        )
        for spec in diff.removed {
            if let node = presentSprites.removeValue(forKey: spec) {
                node.removeFromParent()
                if buildingNodes[spec.coord] === node { buildingNodes.removeValue(forKey: spec.coord) }
            }
        }
        for spec in diff.added {
            let node = placedNode(for: spec)
            addChild(node)
            presentSprites[spec] = node
            if case .building = spec.kind, let sprite = node as? SKSpriteNode { buildingNodes[spec.coord] = sprite }
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
        selectionProvider: (@MainActor @Sendable () -> TileCoordinate?)? = nil,
        routeOverlayProvider: (@MainActor @Sendable () -> IsoWorldScene.RouteOverlay?)? = nil,
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
        if let selectionProvider {
            prepared.selectionProvider = { selectionProvider() }
        }
        if let routeOverlayProvider {
            prepared.routeOverlayProvider = { routeOverlayProvider() }
        }
        if let cameraListener {
            prepared.cameraListener = { tile in cameraListener(tile) }
        }
        // Retain the bridge by parking it on the scene.
        prepared.userData = ["__snapshotBridge": bridge]
        _scene = State(initialValue: prepared)
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
            .onChange(of: reduceMotion, initial: true) { _, isOn in
                scene.reduceMotion = isOn
            }
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
