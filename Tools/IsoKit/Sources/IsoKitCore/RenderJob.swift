import CoreGraphics
import Foundation

/// Renders recipes into a directory of RGBA PNGs: `<sprite>.png` (@1x) and `<sprite>@2x.png`.
/// `scripts/art/finalize.py` quantizes them into the atlases (design D8).
public struct RenderJob {
    public let recipes: [Recipe]
    public let output: URL
    public let scales: [Int]

    public init(recipes: [Recipe], output: URL, scales: [Int] = [1, 2]) {
        self.recipes = recipes
        self.output = output
        self.scales = scales
    }

    /// Writes every sprite; returns the file names written, in order.
    @discardableResult
    public func run(log: (String) -> Void = { _ in }) throws -> [String] {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        var written: [String] = []
        for recipe in recipes {
            let started = Date()
            for scale in scales {
                written += try render(recipe, scale: scale)
            }
            log(String(
                format: "%@: %d sprites in %.2fs",
                recipe.id,
                recipe.spriteNames.count * scales.count,
                Date().timeIntervalSince(started)
            ))
        }
        return written
    }

    func render(_ recipe: Recipe, scale: Int) throws -> [String] {
        let base = try Renderer.image(recipe.scene(stage: .finished), cell: recipe.cell, scale: scale)
        // A moving part belongs to the idle sprite too (a mill at rest still has sails): idle shows frame 0.
        let overlays = try (0 ..< max(recipe.operationalFrames, 1)).map { frame in
            try recipe.movingFrame(frame).map { try Renderer.image($0, cell: recipe.cell, scale: scale) }
        }
        let idle = try overlays[0].map { try Renderer.composite(base, $0) } ?? base
        var images: [(String, CGImage)] = [(recipe.id, idle)]
        for index in 0 ..< recipe.constructionFrames {
            let frame = try Renderer.image(recipe.scene(stage: .constructing(index)), cell: recipe.cell, scale: scale)
            images.append(("\(recipe.id)-constructing-\(index)", frame))
        }
        for index in 0 ..< recipe.operationalFrames {
            let frame = try overlays[index].map { try Renderer.composite(base, $0) } ?? idle
            images.append(("\(recipe.id)-operational-\(index)", frame))
        }
        return try images.map { name, image in
            let file = scale == 1 ? "\(name).png" : "\(name)@\(scale)x.png"
            try Renderer.writePNG(image, to: output.appendingPathComponent(file))
            return file
        }
    }
}
