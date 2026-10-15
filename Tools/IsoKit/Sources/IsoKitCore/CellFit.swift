import Foundation
import SceneKit

/// Where world points land in a sprite cell, in @1x points measured from the cell's bottom-centre
/// anchor (x to the right, y up). Pure maths, so it runs without a GPU.
public enum Projection {
    static let right = SCNVector3(Iso.invRoot2, 0, -Iso.invRoot2)

    public static func screen(_ point: SCNVector3, in cell: SpriteCell) -> CGPoint {
        let anchor = SCNVector3(cell.sizeMetres, 0, cell.sizeMetres)
        let rel = point - anchor
        return CGPoint(
            x: CGFloat(cell.widthPx) / 2 + rel.dot(right) * Iso.pxPerMetre,
            y: rel.dot(Iso.up) * Iso.pxPerMetre
        )
    }
}

/// Checks that nothing a recipe builds is clipped by its cell.
public enum CellFit {
    struct Bounds {
        var min: SCNVector3
        var max: SCNVector3
    }

    /// World-space corners of every geometry under `root`.
    static func corners(of root: SCNNode) -> [SCNVector3] {
        var points: [SCNVector3] = []
        root.enumerateHierarchy { node, _ in
            guard let geometry = node.geometry else { return }
            let (lo, hi) = geometry.boundingBox
            for x in [lo.x, hi.x] {
                for y in [lo.y, hi.y] {
                    for depth in [lo.z, hi.z] {
                        points.append(node.convertPosition(SCNVector3(x, y, depth), to: nil))
                    }
                }
            }
        }
        return points
    }

    static func worldBounds(of root: SCNNode) -> Bounds {
        let points = corners(of: root)
        guard let first = points.first else { return Bounds(min: SCNVector3(0, 0, 0), max: SCNVector3(0, 0, 0)) }
        return points.reduce(Bounds(min: first, max: first)) { bounds, point in
            Bounds(
                min: SCNVector3(min(bounds.min.x, point.x), min(bounds.min.y, point.y), min(bounds.min.z, point.z)),
                max: SCNVector3(max(bounds.max.x, point.x), max(bounds.max.y, point.y), max(bounds.max.z, point.z))
            )
        }
    }

    /// The plot slab overhangs the footprint by 12 cm (about 1 pt) on purpose, to be cropped.
    static let edgeTolerance: CGFloat = 1.5

    /// Human-readable problems, one per clipped edge; empty when the recipe fits at every stage.
    public static func problems(in recipe: Recipe) -> [String] {
        var problems: [String] = []
        for stage in recipe.allStages {
            let points = corners(of: recipe.build(stage: stage)).map { Projection.screen($0, in: recipe.cell) }
            let top = points.map(\.y).max() ?? 0
            let left = points.map(\.x).min() ?? 0
            let right = points.map(\.x).max() ?? 0
            if top > CGFloat(recipe.cell.heightPx) {
                problems.append("\(recipe.id) \(stage): top at \(Int(top.rounded(.up))) pt exceeds cell height \(recipe.cell.heightPx)")
            }
            if left < -edgeTolerance || right > CGFloat(recipe.cell.widthPx) + edgeTolerance {
                problems.append("\(recipe.id) \(stage): spans \(Int(left))…\(Int(right)) pt outside width \(recipe.cell.widthPx)")
            }
        }
        return problems
    }
}
