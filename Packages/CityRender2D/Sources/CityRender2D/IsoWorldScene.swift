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
        case .occupiedMarker:
            return makeOccupiedMarker()
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

    private func makeOccupiedMarker() -> SKNode {
        let radius = IsoMath.tileHeight / 3
        let node = SKShapeNode(circleOfRadius: radius)
        node.fillColor = SKColor(red: 0.95, green: 0.85, blue: 0.35, alpha: 1)
        node.strokeColor = SKColor.black.withAlphaComponent(0.3)
        node.lineWidth = 0.5
        node.zPosition = 10
        return node
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

#if canImport(SwiftUI)
/// SwiftUI host for the snapshot-driven iso scene. App shells construct
/// this with a closure that yields the current snapshot.
@MainActor
public struct IsoWorldView: View {
    @State private var scene: IsoWorldScene

    public init(snapshotProvider: @escaping @MainActor @Sendable () -> WorldSnapshot?) {
        let prepared = IsoWorldScene()
        prepared.size = CGSize(width: 1024, height: 768)
        prepared.scaleMode = .resizeFill
        let bridge = SnapshotProviderBridge(provider: snapshotProvider)
        prepared.dataSource = bridge
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
