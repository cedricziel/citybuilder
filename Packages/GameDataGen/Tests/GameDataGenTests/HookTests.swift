import Foundation
import GameDataModel
import Testing

/// A repository checkout with the fixture packs under the real data path.
private func checkout(core: String = Fixtures.core) throws -> URL {
    let root = try scratch()
    let packs = [("core", core), ("cultures/northern-european", Fixtures.culture), ("ages", Fixtures.ages)]
    try write(Fixtures.source(packs), to: root.appendingPathComponent("Packages/CityCore/GameData"))
    return root
}

/// Claude Code hook input for an edit to `path`; neither string holds
/// quotes or backslashes.
private func input(tool: String = "Edit", path: String, newText: String = "b") -> Data {
    Data(#"""
    {"hook_event_name": "PostToolUse", "tool_name": "\#(tool)",
     "tool_input": {"file_path": "\#(path)", "old_string": "a", "new_string": "\#(newText)"}}
    """#.utf8)
}

/// Runs `gamedata-gen hook <phase>` with `input` on stdin.
private func hook(_ phase: String, _ input: Data) -> GameDataCommand.Outcome {
    GameDataCommand.run(["hook", phase], standardInput: { input }, currentDirectory: URL(fileURLWithPath: "/"))
}

@Test("scenario: invalid pack edit is reported to the agent")
func invalidPackEditIsReportedToTheAgent() throws {
    let root = try checkout(core: Fixtures.core.replacingOccurrences(
        of: "recipe: { inputs: { wood: 1 }", with: "recipe: { inputs: { stone: 1 }"
    ))
    let pack = root.appendingPathComponent("Packages/CityCore/GameData/packs/core.yaml").path

    let result = hook("post", input(path: pack))

    #expect(result.status == 2)
    #expect(result.error.contains("packs/core.yaml"))
    #expect(result.error.contains("Building sawmill"))
    #expect(result.error.contains("stone"))
}

@Test func validPackEditPasses() throws {
    let root = try checkout()
    let pack = root.appendingPathComponent("Packages/CityCore/GameData/packs/core.yaml").path

    #expect(hook("post", input(tool: "Write", path: pack)) == GameDataCommand.Outcome(status: 0))
}

@Test("scenario: hand edit of generated code is blocked")
func handEditOfGeneratedCodeIsBlocked() throws {
    let root = try checkout()
    let generated = root.appendingPathComponent("Packages/CityCore/Sources/CityCore/Generated/Good.swift").path

    for tool in ["Edit", "Write", "MultiEdit"] {
        let result = hook("pre", input(tool: tool, path: generated))
        #expect(result.status == 2)
        #expect(result.error.contains("Packages/CityCore/GameData"))
        #expect(result.error.contains("make gamedata"))
    }
}

@Test("scenario: unrelated edit passes through")
func unrelatedEditPassesThrough() throws {
    // An invalid pack in the checkout: only a pass-through that skips
    // validation entirely leaves the result clean.
    let root = try checkout(core: "not: [valid")
    let other = root.appendingPathComponent("Packages/CityCore/Sources/CityCore/World.swift").path

    for phase in ["pre", "post"] {
        #expect(hook(phase, input(path: other)) == GameDataCommand.Outcome(status: 0))
    }
}

@Test func packEditsAreNotBlockedBeforeTheyHappen() throws {
    let root = try checkout(core: "not: [valid")
    let pack = root.appendingPathComponent("Packages/CityCore/GameData/packs/core.yaml").path

    #expect(hook("pre", input(path: pack)).status == 0)
}

@Test func hookInputItCannotReadFailsOpen() {
    for raw in ["", "not json", #"{"tool_input": {}}"#, #"{"tool_input": {"file_path": 3}}"#] {
        #expect(hook("pre", Data(raw.utf8)).status == 0, "\(raw)")
    }
}

// The script reads the edited path with plutil, so its tests run on macOS,
// where Claude Code runs it.
#if os(macOS)
/// Runs `scripts/gamedata-hook.sh` with `input` and returns its exit
/// status and standard error.
private func runScript(_ phase: String, input: Data) throws -> (Int32, String) {
    let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("../../../..").standardizedFileURL
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = [repository.appendingPathComponent("scripts/gamedata-hook.sh").path, phase]
    process.environment = ["PATH": "/usr/bin:/bin"]
    let stdin = Pipe(), stderr = Pipe()
    process.standardInput = stdin
    process.standardError = stderr
    try process.run()
    stdin.fileHandleForWriting.write(input)
    try stdin.fileHandleForWriting.close()
    let message = String(bytes: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    process.waitUntilExit()
    return (process.terminationStatus, message)
}

@Test func theHookScriptLetsAnEditMentioningGameDataThrough() throws {
    // The README's text names both directories; only its path counts.
    let text = "see Packages/CityCore/GameData/packs/core.yaml and Packages/CityCore/Sources/CityCore/Generated/Good.swift"
    for phase in ["pre", "post"] {
        let (status, message) = try runScript(phase, input: input(path: "/repo/README.md", newText: text))
        #expect(status == 0)
        #expect(message.isEmpty)
    }
}

@Test func theHookScriptBlocksAHandEditOfGeneratedCodeWithoutBuilding() throws {
    // No checkout at this path, so nothing could be built: the block is
    // decided in the script.
    let generated = "/nonexistent/Packages/CityCore/Sources/CityCore/Generated/Good.swift"
    let (status, message) = try runScript("pre", input: input(path: generated))

    #expect(status == 2)
    #expect(message.contains("make gamedata"))
}

@Test func theHookScriptFailsOpenWhenTheGeneratorCannotBeBuilt() throws {
    // A checkout with invalid packs but no generator package: the build
    // fails, and the edit goes through rather than being reported.
    let root = try checkout(core: "not: [valid")
    let pack = root.appendingPathComponent("Packages/CityCore/GameData/packs/core.yaml").path
    let (status, message) = try runScript("post", input: input(path: pack))

    #expect(status == 0)
    #expect(message.isEmpty)
}
#endif
