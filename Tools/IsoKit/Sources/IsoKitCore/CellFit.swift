import Foundation
import SceneKit

/// Where world points land in a sprite cell, in @1x points measured from the cell's bottom-centre
/// anchor (x to the right, y up). Pure maths, so it runs without a GPU.
public enum Projection {
    static let right = SCNVector3(Iso.invRoot2, 0, -Iso.invRoot2)

    public static func screen(_ point: SCNVector3, in cell: SpriteCell) -> CGPoint {
        let rel = point - cell.anchor
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

    /// The plot slab overhangs the footprint by 12 cm (about 1 pt) on purpose, to be cropped. A unit
    /// has no plot, so nothing of it may cross the cell's edge.
    static func edgeTolerance(for recipe: Recipe) -> CGFloat {
        recipe.unit ? 0 : 1.5
    }

    /// What each check covers: every construction stage, or for a unit every frame with its moving part.
    static func fitBuilds(of recipe: Recipe) -> [(label: String, root: SCNNode)] {
        guard recipe.unit else { return recipe.allStages.map { ("\($0)", recipe.build(stage: $0)) } }
        return (0 ..< recipe.operationalFrames).map { ("frame \($0)", recipe.unitModel($0)) }
    }

    /// Where the sun casts `point` onto the ground.
    static func shadow(of point: SCNVector3) -> SCNVector3 {
        let sun = Rig.sunOffset
        return point - sun * (point.y / sun.y)
    }

    /// A unit has no plot to hide its edges: its feet and its baked shadow (with a point of penumbra) must
    /// stay inside the cell on the left, the right and the bottom, or the sprite shows a hard cut.
    static let unitShadowMargin: CGFloat = 0.5

    static func unitProblems(_ recipe: Recipe, _ stage: String, _ corners: [SCNVector3]) -> [String] {
        let body = corners.map { Projection.screen($0, in: recipe.cell) }
        let shade = corners.filter { $0.y > 0.01 }.map { Projection.screen(shadow(of: $0), in: recipe.cell) }
        var problems: [String] = []
        if let bottom = body.map(\.y).min(), bottom < 0 {
            problems.append("\(recipe.id) \(stage): bottom at \(String(format: "%.1f", bottom)) pt is below the cell")
        }
        let margin = unitShadowMargin, width = CGFloat(recipe.cell.widthPx)
        let left = shade.map(\.x).min() ?? margin, right = shade.map(\.x).max() ?? margin
        let low = shade.map(\.y).min() ?? margin
        if left < margin || right > width - margin || low < margin {
            problems.append(String(
                format: "%@ %@: shadow reaches %.1f…%.1f pt across and %.1f pt up, outside %d pt with a %.0f pt margin",
                recipe.id, stage, left, right, low, recipe.cell.widthPx, margin
            ))
        }
        return problems
    }

    /// Human-readable problems, one per clipped edge; empty when the recipe fits at every stage.
    public static func problems(in recipe: Recipe) -> [String] {
        var problems: [String] = []
        let edgeTolerance = edgeTolerance(for: recipe)
        for (stage, root) in fitBuilds(of: recipe) {
            let world = corners(of: root)
            if recipe.unit { problems += unitProblems(recipe, stage, world) }
            let points = world.map { Projection.screen($0, in: recipe.cell) }
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
