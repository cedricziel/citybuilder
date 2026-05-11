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
    private let cameraNode = SKCameraNode()

    override public func didMove(to _: SKView) {
        backgroundColor = SKColor(red: 0.05, green: 0.08, blue: 0.12, alpha: 1)
        scaleMode = .resizeFill
        addChild(cameraNode)
        camera = cameraNode
    }

    #if canImport(UIKit)
    override public func touchesEnded(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        dispatchTap(at: location)
    }

    #elseif canImport(AppKit)
    override public func mouseUp(with event: NSEvent) {
        let location = event.location(in: self)
        dispatchTap(at: location)
    }
    #endif

    private func dispatchTap(at sceneLocation: CGPoint) {
        guard let snapshot = dataSource?.currentSnapshot() else { return }
        if let intent = InputTranslator.tapIntent(
            atScreenPoint: sceneLocation,
            mapWidth: snapshot.mapWidth,
            mapHeight: snapshot.mapHeight
        ) {
            intentSink?(intent)
        }
    }

    override public func update(_: TimeInterval) {
        guard let snapshot = dataSource?.currentSnapshot() else { return }
        applyCamera(snapshot.camera)
        reconcileSprites(with: snapshot)
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
        let path = makeDiamondPath()
        let node = SKShapeNode(path: path)
        node.fillColor = TerrainPalette.color(for: kind)
        node.strokeColor = SKColor.black.withAlphaComponent(0.15)
        node.lineWidth = 0.5
        node.zPosition = 0
        return node
    }

    /// Draw a building as a single diamond spanning its footprint. Real
    /// per-kind art lands later; this placeholder is shaped and colored
    /// so the four-pillar artefact (one marker per occupied tile) is
    /// gone and the player can tell buildings apart.
    private func makeBuildingNode(kind: BuildingKind, state: BuildingState, footprint: Footprint) -> SKNode {
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
        intentSink: (@MainActor @Sendable (Intent) -> Void)? = nil
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
