import SceneKit

/// The rules every recipe obeys at every stage and in every moving-part frame (design D3): no lights
/// of its own, only materials from the shared finish set. `isokit check` and the tests both run them.
public enum RecipeRules {
    /// Every node tree a recipe can produce: each stage, and each moving-part frame.
    static func builds(of recipe: Recipe) -> [(label: String, root: SCNNode)] {
        var builds = recipe.allStages.map { ("\($0)", recipe.build(stage: $0)) }
        if let moving = recipe.moving {
            for frame in 0 ..< max(recipe.operationalFrames, 1) {
                let part = Builder()
                moving.build(part, frame)
                builds.append(("\(moving.name) frame \(frame)", part.root))
            }
        }
        return builds
    }

    public static func problems(in recipe: Recipe) -> [String] {
        var problems: [String] = []
        for (label, root) in builds(of: recipe) {
            root.enumerateHierarchy { node, _ in
                if node.light != nil {
                    problems.append("\(recipe.id) \(label): adds a light")
                }
                for material in node.geometry?.materials ?? [] where !Finish.isShared(material) {
                    problems.append("\(recipe.id) \(label): material \(material.name ?? "unnamed") is outside the finish set")
                }
            }
        }
        return problems
    }
}
