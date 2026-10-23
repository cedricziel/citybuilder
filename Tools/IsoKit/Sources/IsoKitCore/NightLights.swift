import AppKit
import SceneKit

/// Night lights: a few of a building's window panes glowing as if lamps were lit behind them. Each lit
/// building ships `lightsVariants` evenings (`<id>-lights-<n>`); the game picks one per building.
public enum NightLights {
    public static let variants = 3
    /// Oil-lamp amber, and a dimmer amber for the glass bands that span a whole storey.
    static let lamp = NSColor(red: 0.92, green: 0.55, blue: 0.20, alpha: 1)
    static let band = NSColor(red: 0.52, green: 0.34, blue: 0.14, alpha: 1)

    /// How many of `panes` are lit: about 30%, at least one, and no more than three on a small house.
    static func litCount(panes: Int) -> Int {
        let share = Int((Double(panes) * 0.3).rounded())
        return max(1, min(share, panes <= 12 ? 3 : panes))
    }

    /// The indices of the lit panes, given each pane's height. Lower panes are likelier: people sit
    /// downstairs in the evening, and the top floor is mostly dark.
    static func pick(heights: [CGFloat], seed: UInt64) -> Set<Int> {
        guard let low = heights.min(), let high = heights.max() else { return [] }
        let span = max(high - low, 0.001)
        var weights = heights.map { 1.0 - 0.8 * ($0 - low) / span }
        var rng = Rng(state: seed)
        var lit: Set<Int> = []
        for _ in 0 ..< litCount(panes: heights.count) {
            // Weighted draw without replacement: walk the weights until the roll is spent.
            var roll = rng.next() * weights.reduce(0, +)
            var index = weights.lastIndex { $0 > 0 } ?? 0
            for (candidate, weight) in weights.enumerated() where weight > 0 {
                roll -= weight
                if roll <= 0 {
                    index = candidate
                    break
                }
            }
            lit.insert(index)
            weights[index] = 0
        }
        return lit
    }

    /// A stable 64-bit FNV-1a hash, so a recipe's evenings never change between runs or machines.
    static func seed(_ text: String) -> UInt64 {
        text.utf8.reduce(14_695_981_039_346_656_037) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
    }
}

public extension Recipe {
    /// One evening's lights: the finished building with a seeded few panes glowing, unlit, and
    /// everything else, the dark panes included, drawn to depth only and first, so it hides what is
    /// behind it but leaves no colour. A new `attempt` reseeds, for when every chosen pane is hidden.
    /// Nil when the building has no pane.
    func lightsScene(variant: Int, attempt: Int = 0) -> SCNNode? {
        let root = build(stage: .finished)
        var panes: [SCNNode] = []
        root.enumerateHierarchy { node, _ in
            if node.geometry?.materials.contains(where: Finish.isPane) == true { panes.append(node) }
        }
        guard !panes.isEmpty else { return nil }
        let picked = NightLights.pick(heights: panes.map(\.worldPosition.y), seed: NightLights.seed("\(id)#\(variant)#\(attempt)"))
        let lit = Set(picked.map { ObjectIdentifier(panes[$0]) })
        root.enumerateHierarchy { node, _ in
            let glows = lit.contains(ObjectIdentifier(node))
            node.renderingOrder = glows ? 1 : -1
            guard let geometry = node.geometry?.copy() as? SCNGeometry else { return }
            geometry.materials = geometry.materials.map { material in
                guard glows, Finish.isPane(material) else {
                    let hidden = material.copy() as? SCNMaterial ?? material
                    hidden.colorBufferWriteMask = []
                    return hidden
                }
                let glow = SCNMaterial()
                glow.lightingModel = .constant
                glow.diffuse.contents = material.name == Finish.namePrefix + "\(Finish.glazing)" ? NightLights.band : NightLights.lamp
                return glow
            }
            node.geometry = geometry
        }
        return root
    }
}
