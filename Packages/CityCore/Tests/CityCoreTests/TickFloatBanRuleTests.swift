import Foundation
import Testing

// Metadata tests for the `tick_float_ban` SwiftLint custom rule
// defined in `.swiftlint.yml`. The rule itself is enforced by
// SwiftLint at lint time; these tests assert the rule's
// configuration so a future edit can't silently weaken it.

private func swiftlintConfig() throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // CityCoreTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // CityCore
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // worktree root
    let path = root.appendingPathComponent(".swiftlint.yml").path
    return try String(contentsOfFile: path, encoding: .utf8)
}

@Test("scenario: swiftlint rule flags double in tick path")
func scenarioSwiftLintRuleFlagsDoubleInTickPath() throws {
    let yml = try swiftlintConfig()
    // Rule is registered under custom_rules and named tick_float_ban.
    #expect(yml.contains("tick_float_ban:"))
    // Banned tokens appear in the regex.
    #expect(yml.contains("Float"))
    #expect(yml.contains("Double"))
    #expect(yml.contains("CGFloat"))
    // Rule fires only on the type-identifier kind so prose comments
    // and identifier-positioned occurrences don't trip it.
    #expect(yml.contains("typeidentifier"))
    // Rule scopes to CityCore/Systems/ so the Systems subdirectory is
    // the tick-time fence.
    #expect(yml.contains("Sources/CityCore/Systems/"))
    // Rule is an error, not a warning — the gate is hard.
    #expect(yml.contains("severity: error"))
}

@Test("scenario: renderer is exempt from the ban")
func scenarioRendererIsExemptFromTheBan() throws {
    let yml = try swiftlintConfig()
    // The rule's `included:` scope mentions CityCore/Systems/ only;
    // CityRender2D paths are not in the scope. A regex match for
    // `Packages/CityRender2D` inside the tick_float_ban block would
    // indicate the renderer was scoped in.
    let lines = yml.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    guard let startIdx = lines.firstIndex(where: { $0.contains("tick_float_ban:") }) else {
        Issue.record("expected tick_float_ban: block in .swiftlint.yml")
        return
    }
    let blockEnd = lines[(startIdx + 1)...].firstIndex(where: { line in
        !line.isEmpty && !line.first!.isWhitespace
    }) ?? lines.endIndex
    let block = lines[startIdx ..< blockEnd].joined(separator: "\n")
    #expect(!block.contains("CityRender2D"))
    #expect(!block.contains("CityUI"))
}
