import Foundation
import Testing
@testable import IsoKitCore

struct CatalogSelectionTests {
    @Test("scenario: Every catalogued building kind has a recipe")
    func everyCataloguedKindHasARecipe() throws {
        let catalog = try Catalog.load(directory: RepoPaths.catalog)
        #expect(!catalog.entries.isEmpty)
        let problems = RecipeRegistry.mismatches(recipes: Recipes.all, catalog: catalog)
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test("an isokit entry without a recipe is reported")
    func isokitEntryWithoutRecipe() {
        let catalog = Catalog(entries: [CatalogEntry(id: "building-nowhere", source: "isokit")])
        let problems = RecipeRegistry.mismatches(recipes: [], catalog: catalog)
        #expect(problems == ["building-nowhere declares source = \"isokit\" but has no IsoKit recipe"])
    }

    @Test("a recipe without a catalog entry is reported")
    func recipeWithoutEntry() {
        let recipe = Recipe(id: "building-orphan", cell: SpriteCell(footprint: 1, heightPx: 64)) { _, _ in }
        let problems = RecipeRegistry.mismatches(recipes: [recipe], catalog: Catalog(entries: []))
        #expect(problems == ["recipe building-orphan has no catalog entry"])
    }

    @Test("scenario: Entries not yet migrated are left alone")
    func unmigratedEntriesAreLeftAlone() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("isokit-catalog-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try "---\nsource = \"procedural\"\n---\n## Function\n".write(
            to: dir.appendingPathComponent("building-bakery.md"), atomically: true, encoding: .utf8
        )
        try "---\nsource = \"isokit\"\n---\n## Function\n".write(
            to: dir.appendingPathComponent("building-house.md"), atomically: true, encoding: .utf8
        )
        let catalog = try Catalog.load(directory: dir)
        let selected = RenderSelection.recipes(Recipes.all, migratedIn: catalog)
        #expect(Set(selected.map(\.entry)) == ["building-house"])
        #expect(!selected.contains { $0.id.hasPrefix("building-bakery") })
    }

    @Test("a migrated entry's recipes must render exactly the sprites its brief lists")
    func migratedEntryNamesMatchBrief() {
        let entry = CatalogEntry(id: "building-house", source: "isokit", spriteNames: ["building-house", "building-house-tier2"])
        let house = Recipe(id: "building-house", cell: SpriteCell(footprint: 2, heightPx: 112), constructionFrames: 0) { _, _ in }
        #expect(RecipeRegistry.mismatches(recipes: [house], catalog: Catalog(entries: [entry])) == [
            "building-house sprite names differ from its brief: missing [\"building-house-tier2\"], extra []"
        ])
        let tier2 = Recipe(
            id: "building-house-tier2", entry: "building-house", cell: SpriteCell(footprint: 2, heightPx: 144), constructionFrames: 0
        ) { _, _ in }
        #expect(RecipeRegistry.mismatches(recipes: [house, tier2], catalog: Catalog(entries: [entry])).isEmpty)
    }

    @Test("sheet lines yield sprite names and skip spare cells")
    func sheetNamesParsing() {
        let text = "## Sheet\n\n- (0, 0): `building-house` — base\n- (0, 1): `building-house-constructing-0` — x\n- (1, 2): spare\n"
        #expect(CatalogEntry.spriteNames(fromMarkdown: text) == ["building-house", "building-house-constructing-0"])
    }

    @Test("front matter source is read and defaults to empty")
    func frontMatterParsing() {
        #expect(CatalogEntry.source(fromMarkdown: "---\nsource = \"isokit\"\n---\nbody") == "isokit")
        #expect(CatalogEntry.source(fromMarkdown: "---\nsource = \"svg\"\nother = 1\n---\n") == "svg")
        #expect(CatalogEntry.source(fromMarkdown: "## Function\nno front matter") == "")
    }

    @Test("sprite names follow the building grammar")
    func spriteNamesFollowGrammar() {
        let recipe = Recipe(id: "building-sawmill", cell: SpriteCell(footprint: 2, heightPx: 128), operationalFrames: 4) { _, _ in }
        #expect(recipe.spriteNames == [
            "building-sawmill",
            "building-sawmill-constructing-0", "building-sawmill-constructing-1", "building-sawmill-constructing-2",
            "building-sawmill-operational-0", "building-sawmill-operational-1",
            "building-sawmill-operational-2", "building-sawmill-operational-3"
        ])
    }
}
