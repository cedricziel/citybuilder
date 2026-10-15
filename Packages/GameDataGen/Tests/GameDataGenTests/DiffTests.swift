import Foundation
import GameDataModel
import Testing

private func diff(_ old: InMemorySource, _ new: InMemorySource) throws -> [String] {
    try ContentDiff.diff(old: old, new: new).get()
}

private func editingCore(_ edit: (String) -> String) -> InMemorySource {
    Fixtures.source([("core", edit(Fixtures.core)), ("cultures/northern-european", Fixtures.culture), ("ages", Fixtures.ages)])
}

@Test("scenario: value change is listed once")
func valueChangeIsListedOnce() throws {
    let old = editingCore { "# Shared producer defaults.\n" + $0 }
    let new = editingCore {
        "# Defaults every producer shares.\n" + $0.replacingOccurrences(
            of: "id: sawmill\n    <<: *producer\n",
            with: "id: sawmill\n    <<: *producer\n    cost: 130\n"
        )
    }

    #expect(try diff(old, new) == ["Building sawmill: cost 120 → 130"])
}

@Test("scenario: anchor change lists every affected item")
func anchorChangeListsEveryAffectedItem() throws {
    let extra = { (cost: Int) in
        """
        defaults:
          mill: &mill
            footprint: [2, 2]
            cost: \(cost)
            recipe: { inputs: { wood: 1 }, outputs: { planks: 1 }, cycleTicks: 20 }
        items:
          - { kind: Building, id: mill-a, <<: *mill }
          - { kind: Building, id: mill-b, <<: *mill }
          - { kind: Building, id: mill-c, <<: *mill }
        """
    }

    #expect(try diff(Fixtures.withExtraPack(extra(90)), Fixtures.withExtraPack(extra(95))) == [
        "Building mill-a: cost 90 → 95",
        "Building mill-b: cost 90 → 95",
        "Building mill-c: cost 90 → 95"
    ])
}

@Test func formattingKeyOrderAndPackMovesAreNotChanges() throws {
    let reordered = editingCore {
        $0.replacingOccurrences(
            of: "{ kind: Good, id: wood, name: Wood, unit: logs, basePrice: 4 }",
            with: "{ basePrice: 4, unit: logs, name: Wood, id: wood, kind: Good }"
        )
    }
    #expect(try diff(Fixtures.source(), reordered).isEmpty)

    let moved = """
    items:
      - { kind: Good, id: salt, name: Salt, unit: sacks, basePrice: 3 }
    """
    let ages = Fixtures.ages + "\n  - { kind: Good, id: salt, name: Salt, unit: sacks, basePrice: 3 }\n"
    let before = Fixtures.withExtraPack(moved)
    let after = Fixtures.source([("core", Fixtures.core), ("cultures/northern-european", Fixtures.culture), ("ages", ages)])
    #expect(try diff(before, after).isEmpty)
}

@Test func additionsAndRemovalsAreListedInLoadOrder() throws {
    let added = """
    items:
      - { kind: Good, id: salt, name: Salt, unit: sacks, basePrice: 3 }
      - { kind: Good, id: brine, name: Brine, unit: barrels, basePrice: 1 }
    """
    let core = Fixtures.core.replacingOccurrences(
        of: "  - { kind: Good, id: planks, name: Planks, unit: bundles, basePrice: 8 }\n", with: ""
    )
    let new = Fixtures.source([
        ("core", core), ("cultures/northern-european", Fixtures.culture), ("ages", Fixtures.ages), ("extra", added)
    ])

    #expect(try diff(Fixtures.source(), new) == [
        "added Good salt",
        "added Good brine",
        "removed Good planks"
    ])
}

@Test func changesComeBeforeAdditions() throws {
    let extra = "items:\n  - { kind: Good, id: salt, name: Salt, unit: sacks, basePrice: 3 }\n"
    let ages = Fixtures.ages.replacingOccurrences(of: "rivalResidents: 24", with: "rivalResidents: 30")
    let new = Fixtures.source([
        ("core", Fixtures.core), ("extra", extra), ("cultures/northern-european", Fixtures.culture), ("ages", ages)
    ])

    #expect(try diff(Fixtures.source(), new) == ["Age medieval: rivalResidents 24 → 30", "added Good salt"])
}

@Test func nestedListAndMarketFieldsAreCompared() throws {
    let new = editingCore {
        $0.replacingOccurrences(of: "basePrice: 4 }", with: "basePrice: 4, market: { buy: 6 } }")
            .replacingOccurrences(of: "cost: 80\n    storage: 16", with: "cost: 80\n    plantTicks: 40\n    storage: 16")
            .replacingOccurrences(
                of: "recipe: { inputs: { wood: 1 }, outputs: { planks: 1 }, cycleTicks: 25 }",
                with: "recipe: { inputs: { wood: 2 }, outputs: { planks: 1 }, cycleTicks: 25 }"
            )
            .replacingOccurrences(of: "footprint: [2, 3]", with: "footprint: [3, 3]")
    }

    #expect(try diff(Fixtures.source(), new) == [
        "Good wood: market.buy (none) → 6",
        "Building lumberjack-hut: plantTicks (none) → 40",
        "Building sawmill: recipe.inputs.wood 1 → 2",
        "Building port: footprint [2, 3] → [3, 3]"
    ])
}

@Test func unreadablePackIsReported() {
    let broken = editingCore { $0 + "\n  - [unclosed" }

    #expect(throws: GameDataErrors.self) { try ContentDiff.diff(old: Fixtures.source(), new: broken).get() }
}

/// A git repository with the fixture packs committed under the real data
/// path, then the planks' base price edited in the working tree.
private func repositoryWithAnEditedPack() throws -> URL {
    let repo = try scratch()
    let data = repo.appendingPathComponent("Packages/CityCore/GameData")
    try write(Fixtures.source(), to: data)
    func run(_ arguments: String...) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "-C", repo.path, "-c", "user.name=t", "-c", "user.email=t@t", "-c", "commit.gpgsign=false"]
            + arguments
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }
    try run("init", "-q")
    try run("add", ".")
    try run("commit", "-q", "-m", "packs")
    let edited = Fixtures.core.replacingOccurrences(of: "basePrice: 8", with: "basePrice: 9")
    try edited.write(to: data.appendingPathComponent("packs/core.yaml"), atomically: true, encoding: .utf8)
    return repo
}

@Test func gitRevisionIsReadThroughGitShow() throws {
    let data = try repositoryWithAnEditedPack().appendingPathComponent("Packages/CityCore/GameData")

    let old = GitSource(revision: "HEAD", dataDirectory: data)

    #expect(try ContentDiff.diff(old: old, new: DirectorySource(root: data)).get() == ["Good planks: basePrice 8 → 9"])
}

@Test func theDiffCommandWorksFromAnyDirectoryOfTheCheckout() throws {
    let repo = try repositoryWithAnEditedPack()
    let packages = repo.appendingPathComponent("Packages")

    let fromRoot = GameDataCommand.run(["diff", "HEAD"], standardInput: { Data() }, currentDirectory: repo)
    let fromPackages = GameDataCommand.run(
        ["diff", "HEAD", "--data", "CityCore/GameData"], standardInput: { Data() }, currentDirectory: packages
    )

    #expect(fromRoot == GameDataCommand.Outcome(status: 0, output: "Good planks: basePrice 8 → 9\n"))
    #expect(fromPackages == fromRoot)
}

@Test func theDiffCommandReportsARevisionGitCannotRead() throws {
    let repo = try repositoryWithAnEditedPack()

    let result = GameDataCommand.run(["diff", "no-such-ref"], standardInput: { Data() }, currentDirectory: repo)

    #expect(result.status == 1)
    // Git's own message follows, in the user's locale.
    let prefix = "cannot read no-such-ref: "
    #expect(result.error.hasPrefix(prefix))
    #expect(result.error.count > prefix.count + 1)
}
