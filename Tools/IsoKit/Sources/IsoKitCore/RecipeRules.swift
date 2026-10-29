import SceneKit

/// The rules every recipe obeys at every stage and in every moving-part frame (design D3): no lights
/// of its own, no glowing material, only materials from the shared finish set, and the self-lit flame
/// in effects only. `isokit check` and the tests both run them.
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
                for material in node.geometry?.materials ?? [] {
                    if Finish.isFlame(material), !recipe.id.hasPrefix("effect-") {
                        problems.append("\(recipe.id) \(label): material \(Finish.flameName) is self-lit outside an effect")
                    }
                    if !Finish.isShared(material) {
                        problems.append("\(recipe.id) \(label): material \(material.name ?? "unnamed") is outside the finish set")
                    }
                    // Window light belongs to the night-lights masks; a sprite that glows glows all day.
                    if emits(material) { problems.append("\(recipe.id) \(label): material \(material.name ?? "unnamed") glows") }
                }
            }
        }
        return problems
    }

    private static func emits(_ material: SCNMaterial) -> Bool {
        guard let colour = (material.emission.contents as? NSColor)?.usingColorSpace(.deviceRGB) else {
            return material.emission.contents != nil
        }
        return colour.redComponent + colour.greenComponent + colour.blueComponent > 0
    }
}
