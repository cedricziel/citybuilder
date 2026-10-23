// isokit: render building and unit sprites from IsoKit recipes (capability `iso-art-kit`).
//
//   isokit render --catalog <dir> --out <dir> [--all] [--only <id>] [--scales 1,2]
//       Renders recipes whose catalog entry declares source = "isokit" (or every recipe with --all)
//       to RGBA PNGs in <dir>. `make sprites` quantizes them into the atlases. --only renders one
//       recipe, as `make app-icon` does at 8x.
//   isokit check --catalog <dir>
//       Recipe/catalog agreement and cell fit. Needs no GPU.
//   isokit chimneys --catalog <dir>
//       The chimney top of every migrated recipe that builds one, as `ChimneyAnchors` rows. Needs no GPU.
import Foundation
import IsoKitCore

struct Options {
    var command = ""
    var catalog = URL(fileURLWithPath: "Resources/Sprites.style/catalog")
    var output: URL?
    var all = false
    var only: String?
    var scales = [1, 2]

    init(_ arguments: [String]) throws {
        var rest = arguments.dropFirst()
        command = rest.popFirst() ?? ""
        while let flag = rest.popFirst() {
            switch flag {
            case "--catalog": catalog = try URL(fileURLWithPath: Self.value(flag, &rest))
            case "--out": output = try URL(fileURLWithPath: Self.value(flag, &rest))
            case "--all": all = true
            case "--only": only = try Self.value(flag, &rest)
            case "--scales": scales = try Self.value(flag, &rest).split(separator: ",").compactMap { Int($0) }
            default: throw UsageError("unknown option \(flag)")
            }
        }
    }

    static func value(_ flag: String, _ rest: inout ArraySlice<String>) throws -> String {
        guard let value = rest.popFirst() else { throw UsageError("\(flag) needs a value") }
        return value
    }
}

struct UsageError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) {
        self.description = description
    }
}

func run() throws -> Int32 {
    let options = try Options(CommandLine.arguments)
    let catalog = try Catalog.load(directory: options.catalog)
    let problems = RecipeRegistry.mismatches(recipes: Recipes.all, catalog: catalog)
        + Recipes.all.flatMap(CellFit.problems)
        + Recipes.all.flatMap(RecipeRules.problems)
    switch options.command {
    case "check":
        problems.forEach { print($0) }
        // A warning, not a problem: a workshop may have no window. `isokit render` names the ones whose
        // windows are all hidden.
        for id in NightLights.withoutPanes(Recipes.all) {
            print("warning: \(id) is meant to light up at night but has no window pane")
        }
        print(problems.isEmpty ? "isokit check: \(Recipes.all.count) recipes ok" : "isokit check: \(problems.count) problem(s)")
        return problems.isEmpty ? 0 : 1
    case "chimneys":
        for recipe in RenderSelection.recipes(Recipes.all, migratedIn: catalog) {
            guard let anchor = recipe.chimneyAnchor else { continue }
            print(String(format: "\"%@\": (%.3f, %.3f),", recipe.id, anchor.x, anchor.y))
        }
        return 0
    case "render":
        guard problems.isEmpty else {
            problems.forEach { print($0) }
            return 1
        }
        guard let output = options.output else { throw UsageError("render needs --out <dir>") }
        var recipes = options.all ? Recipes.all : RenderSelection.recipes(Recipes.all, migratedIn: catalog)
        if let only = options.only {
            recipes = recipes.filter { $0.id == only }
            guard !recipes.isEmpty else { throw UsageError("no recipe \(only) to render") }
        }
        let started = Date()
        let written = try RenderJob(recipes: recipes, output: output, scales: options.scales).run { print($0) }
        print(String(
            format: "isokit render: %d file(s) from %d recipe(s) in %.1fs",
            written.count,
            recipes.count,
            Date().timeIntervalSince(started)
        ))
        return 0
    default:
        throw UsageError(
            "usage: isokit render --catalog <dir> --out <dir> [--all] [--only <id>] [--scales 1,2]"
                + " | isokit check|chimneys --catalog <dir>"
        )
    }
}

do {
    try exit(run())
} catch {
    FileHandle.standardError.write(Data("isokit: \(error)\n".utf8))
    exit(2)
}
