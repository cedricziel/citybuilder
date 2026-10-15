import Foundation
import Testing

// `Recipe` sections of the sprite briefs (replace-generative-sprites-with-isokit,
// sprite-style-catalog: Catalog entry declares function, identity and recipe).
struct CatalogRecipeSectionTests {
    private static let catalog = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources/Sprites.style/catalog")

    /// Lines between `## Recipe` and the next level-2 heading.
    private func recipeSection(_ id: String) throws -> [String] {
        let text = try String(contentsOf: Self.catalog.appendingPathComponent("\(id).md"), encoding: .utf8)
        let lines = text.components(separatedBy: "\n")
        guard let start = lines.firstIndex(of: "## Recipe") else { return [] }
        return Array(lines[(start + 1)...].prefix { !$0.hasPrefix("## ") })
    }

    @Test("scenario: Recipe section names a registered recipe")
    func recipeSectionNamesARegisteredRecipe() throws {
        let recipe = try recipeSection("building-sawmill")
        #expect(recipe.contains("- Recipe: `building-sawmill` (IsoKit)"))
        #expect(recipe.contains("- Moving part: sails, 4 frames, sweeps right"))
    }

    @Test("unit briefs name facings and frames, not construction states")
    func unitBriefsNameFacingsAndFrames() throws {
        let walker = try recipeSection("walker")
        #expect(walker.contains("- Facings: ne, nw, se, sw"))
        #expect(walker.contains("- Frames per facing: 4"))
        #expect(!walker.contains { $0.hasPrefix("- Construction stages") })
    }
}
