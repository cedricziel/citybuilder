import Foundation
import SceneKit

/// What a recipe is asked to build.
public enum Stage: Equatable, CustomStringConvertible {
    /// Construction frame 0 (plinth and bare frame), 1 (walls, roof boards), 2 (near-finished, scaffold).
    case constructing(Int)
    case finished

    public var description: String {
        switch self {
        case let .constructing(index): "constructing-\(index)"
        case .finished: "finished"
        }
    }
}

/// A part that moves between operational frames (sails, saw, wheel). Rendered as an overlay
/// with the building drawn depth-only, then composited onto the idle sprite.
public struct MovingPart {
    public let name: String
    public let build: (Builder, Int) -> Void

    public init(name: String, build: @escaping (Builder, Int) -> Void) {
        self.name = name
        self.build = build
    }
}

/// One building look: a sprite stem, the catalog entry it belongs to, a cell, and a build closure
/// made of kit parts. An entry can own several recipes (the house entry holds tiers 1–3).
public struct Recipe {
    public let id: String
    public let entry: String
    public let cell: SpriteCell
    public let constructionFrames: Int
    public let operationalFrames: Int
    public let moving: MovingPart?
    /// True when `body` handles `.constructing` itself; otherwise stages are cut from the finished build.
    public let customStages: Bool
    /// Finish of the plot slab under the whole footprint, or nil for none.
    public let plot: Finish?
    let body: (Builder, Stage) -> Void

    public init(
        id: String,
        entry: String? = nil,
        cell: SpriteCell,
        constructionFrames: Int = 3,
        operationalFrames: Int = 0,
        moving: MovingPart? = nil,
        customStages: Bool = false,
        plot: Finish? = .yard,
        body: @escaping (Builder, Stage) -> Void
    ) {
        self.id = id
        self.entry = entry ?? id
        self.cell = cell
        self.constructionFrames = constructionFrames
        self.operationalFrames = operationalFrames
        self.moving = moving
        self.customStages = customStages
        self.plot = plot
        self.body = body
    }

    public var allStages: [Stage] {
        (0 ..< constructionFrames).map(Stage.constructing) + [.finished]
    }

    /// Atlas sprite names, in render order (naming grammar of `sprite-asset-pipeline`).
    public var spriteNames: [String] {
        [id]
            + (0 ..< constructionFrames).map { "\(id)-constructing-\($0)" }
            + (0 ..< operationalFrames).map { "\(id)-operational-\($0)" }
    }

    /// The recipe's own nodes, without lights or ground.
    public func build(stage: Stage) -> SCNNode {
        let kit = Builder()
        if let plot { kit.plot(size: cell.sizeMetres, plot) }
        if case let .constructing(index) = stage, !customStages {
            body(kit, .finished)
            ConstructionStages.cut(kit.root, frame: index, frames: constructionFrames)
        } else {
            body(kit, stage)
        }
        return kit.root
    }

    /// The recipe plus the shared light rig and the shadow-catching ground.
    public func scene(stage: Stage) -> SCNNode {
        let root = SCNNode()
        root.addChildNode(build(stage: stage))
        Rig.add(to: root, cell: cell)
        root.addChildNode(Rig.shadowCatcher())
        return root
    }

    /// Overlay frame: the building writes depth only, so it occludes and shadows the part
    /// without being drawn; no ground, so the building's shadow is not drawn twice.
    public func movingFrame(_ frame: Int) -> SCNNode? {
        guard let moving else { return nil }
        let root = SCNNode()
        let building = build(stage: .finished)
        building.enumerateHierarchy { node, _ in
            node.geometry?.materials.forEach { $0.colorBufferWriteMask = [] }
        }
        root.addChildNode(building)
        let part = Builder()
        moving.build(part, frame)
        root.addChildNode(part.root)
        Rig.add(to: root, cell: cell)
        return root
    }
}

/// Generic construction frames for recipes that don't stage themselves: keep the geometry that
/// starts below a rising cut, and stand scaffold poles at the corners of what remains.
enum ConstructionStages {
    static func cut(_ root: SCNNode, frame: Int, frames _: Int) {
        let top = CellFit.worldBounds(of: root).max.y
        let fractions: [CGFloat] = [0.12, 0.55, 0.85]
        let cutY = top * fractions[min(frame, fractions.count - 1)] + (frame == 0 ? 0.3 : 0)
        let structure = SCNNode()
        for node in root.childNodes {
            let bounds = CellFit.worldBounds(of: node)
            if bounds.min.y >= cutY {
                node.removeFromParentNode()
            } else if bounds.max.y - bounds.min.y > 0.3 {
                // Paving and yard slabs don't get scaffold; walls and plinths do.
                structure.addChildNode(node.clone())
            }
        }
        let body = CellFit.worldBounds(of: structure)
        let kit = Builder()
        let poleTop = min(max(cutY, 1.5), top)
        // The three corners the camera sees; the back corner is hidden and would project highest.
        let corners = [(body.min.x, body.max.z), (body.max.x, body.max.z), (body.max.x, body.min.z)]
        for (x, depth) in corners {
            kit.block(SCNVector3(x - 0.06, 0, depth - 0.06), SCNVector3(x + 0.06, poleTop, depth + 0.06), .wood)
        }
        root.addChildNode(kit.root)
    }
}
