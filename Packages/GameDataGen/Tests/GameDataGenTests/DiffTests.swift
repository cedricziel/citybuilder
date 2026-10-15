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

@Test func gitRevisionIsReadThroughGitShow() throws {
    let repo = try scratch()
    let data = "Packages/CityCore/GameData"
    try write(Fixtures.source(), to: repo.appendingPathComponent(data))
    func git(_ arguments: String...) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "-C", repo.path, "-c", "user.name=t", "-c", "user.email=t@t", "-c", "commit.gpgsign=false"] + arguments
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }
    try git("init", "-q")
    try git("add", ".")
    try git("commit", "-q", "-m", "packs")
    let edited = Fixtures.core.replacingOccurrences(of: "basePrice: 8", with: "basePrice: 9")
    try edited.write(to: repo.appendingPathComponent("\(data)/packs/core.yaml"), atomically: true, encoding: .utf8)

    let old = GitSource(repository: repo, revision: "HEAD", dataDirectory: data)
    let new = DirectorySource(root: repo.appendingPathComponent(data))

    #expect(try ContentDiff.diff(old: old, new: new).get() == ["Good planks: basePrice 8 → 9"])
}
