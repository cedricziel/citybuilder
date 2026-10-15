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

/// Claude Code hook input for an edit to `path`, which holds no quotes.
private func input(tool: String = "Edit", path: String) -> Data {
    Data(#"""
    {"hook_event_name": "PostToolUse", "tool_name": "\#(tool)",
     "tool_input": {"file_path": "\#(path)", "old_string": "a", "new_string": "b"}}
    """#.utf8)
}

@Test("scenario: invalid pack edit is reported to the agent")
func invalidPackEditIsReportedToTheAgent() throws {
    let root = try checkout(core: Fixtures.core.replacingOccurrences(
        of: "recipe: { inputs: { wood: 1 }", with: "recipe: { inputs: { stone: 1 }"
    ))
    let pack = root.appendingPathComponent("Packages/CityCore/GameData/packs/core.yaml").path

    let result = GameDataHook.run(.post, input: input(path: pack))

    #expect(result.status == 2)
    #expect(result.message.contains("packs/core.yaml"))
    #expect(result.message.contains("Building sawmill"))
    #expect(result.message.contains("stone"))
}

@Test func validPackEditPasses() throws {
    let root = try checkout()
    let pack = root.appendingPathComponent("Packages/CityCore/GameData/packs/core.yaml").path

    #expect(GameDataHook.run(.post, input: input(tool: "Write", path: pack)).status == 0)
}

@Test("scenario: hand edit of generated code is blocked")
func handEditOfGeneratedCodeIsBlocked() throws {
    let root = try checkout()
    let generated = root.appendingPathComponent("Packages/CityCore/Sources/CityCore/Generated/Good.swift").path

    for tool in ["Edit", "Write", "MultiEdit"] {
        let result = GameDataHook.run(.pre, input: input(tool: tool, path: generated))
        #expect(result.status == 2)
        #expect(result.message.contains("Packages/CityCore/GameData"))
        #expect(result.message.contains("make gamedata"))
    }
}

@Test("scenario: unrelated edit passes through")
func unrelatedEditPassesThrough() throws {
    // An invalid pack in the checkout: only a pass-through that skips
    // validation entirely leaves the result clean.
    let root = try checkout(core: "not: [valid")
    let other = root.appendingPathComponent("Packages/CityCore/Sources/CityCore/World.swift").path

    for phase in [GameDataHook.Phase.pre, .post] {
        let result = GameDataHook.run(phase, input: input(path: other))
        #expect(result.status == 0)
        #expect(result.message.isEmpty)
    }
}

@Test func packEditsAreNotBlockedBeforeTheyHappen() throws {
    let root = try checkout(core: "not: [valid")
    let pack = root.appendingPathComponent("Packages/CityCore/GameData/packs/core.yaml").path

    #expect(GameDataHook.run(.pre, input: input(path: pack)).status == 0)
}

@Test func hookInputItCannotReadFailsOpen() {
    for raw in ["", "not json", #"{"tool_input": {}}"#, #"{"tool_input": {"file_path": 3}}"#] {
        let result = GameDataHook.run(.pre, input: Data(raw.utf8))
        #expect(result.status == 0, "\(raw)")
    }
}

/// Runs `scripts/gamedata-hook.sh` with `input` and returns its exit
/// status and standard error.
private func runScript(_ phase: String, input: Data, projectDirectory: String) throws -> (Int32, String) {
    let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("../../../..").standardizedFileURL
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = [repository.appendingPathComponent("scripts/gamedata-hook.sh").path, phase]
    process.environment = ["CLAUDE_PROJECT_DIR": projectDirectory, "PATH": "/usr/bin:/bin"]
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

@Test func theHookScriptLetsUnrelatedEditsThroughWithoutBuilding() throws {
    // No project directory to build in: only the early pass-through
    // exits cleanly with nothing on stderr.
    for phase in ["pre", "post"] {
        let (status, message) = try runScript(phase, input: input(path: "/repo/README.md"), projectDirectory: "/nonexistent")
        #expect(status == 0)
        #expect(message.isEmpty)
    }
}

@Test func theHookScriptFailsOpenWhenTheGeneratorCannotRun() throws {
    let generated = "/repo/Packages/CityCore/Sources/CityCore/Generated/Good.swift"
    let (status, _) = try runScript("pre", input: input(path: generated), projectDirectory: "/nonexistent")

    #expect(status == 0)
}
