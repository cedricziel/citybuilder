import Foundation
import Testing

// Scenarios from openspec/changes/add-playtest-harness. The tests read the persona agents and the
// playtest skill, so a rename or a dropped section fails here and not in the middle of a session.

private let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()

private let personaSlugs = ["newcomer", "optimizer", "builder", "veteran", "trader", "chaos", "returning"]
private let allAgentSlugs = personaSlugs + ["ui-auditor"]

/// What each persona's Device section has to name.
private let deviceMatrix: [String: [String]] = [
    "newcomer": ["iPhone", "portrait"],
    "optimizer": ["iPad", "landscape"],
    "builder": ["iPad", "portrait"],
    "trader": ["iPhone", "landscape"],
    "veteran": ["Mac"],
    "chaos": ["iPhone SE"],
    "returning": ["Pro Max"]
]

private func text(of path: String) throws -> String {
    try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
}

private func agent(_ slug: String) throws -> (frontmatter: [String: String], body: String) {
    let file = try text(of: ".claude/agents/playtester-\(slug).md")
    let parts = file.components(separatedBy: "\n---\n")
    #expect(file.hasPrefix("---\n"), "playtester-\(slug) starts with frontmatter")
    let head = (parts.first ?? "").dropFirst(4)
    var fields: [String: String] = [:]
    for line in head.split(separator: "\n") {
        guard let colon = line.firstIndex(of: ":") else { continue }
        fields[String(line[..<colon])] = line[line.index(after: colon)...].trimmingCharacters(in: CharacterSet(charactersIn: " \""))
    }
    return (fields, parts.dropFirst().joined(separator: "\n---\n"))
}

private let controlTool = "mcp__Claude_Code_iOS_Simulator__control"

@Test("scenario: every persona has an agent file")
func scenarioEveryPersonaHasAnAgentFile() {
    let agents = repoRoot.appendingPathComponent(".claude/agents")
    for slug in personaSlugs {
        let file = agents.appendingPathComponent("playtester-\(slug).md")
        #expect(FileManager.default.fileExists(atPath: file.path), "missing \(file.lastPathComponent)")
    }
}

@Test("scenario: persona frontmatter is complete")
func scenarioPersonaFrontmatterIsComplete() throws {
    for slug in allAgentSlugs {
        let (fields, _) = try agent(slug)
        let raw = try text(of: ".claude/agents/playtester-\(slug).md")
        #expect(fields["name"] == "playtester-\(slug)")
        #expect(fields["description"]?.isEmpty == false, "\(slug) needs a description")
        // An unquoted description with a colon in it is invalid YAML and the agent would not load.
        #expect(raw.contains("\ndescription: \""), "\(slug)'s description is quoted")
        #expect(fields["model"] == "sonnet")
        #expect(fields["effort"] == "medium")
        let tools = (fields["tools"] ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        for tool in ["Bash", "Read", "Write", controlTool] {
            #expect(tools.contains(tool), "\(slug) is missing the \(tool) tool")
        }
    }
}

@Test("scenario: persona bodies cover the player")
func scenarioPersonaBodiesCoverThePlayer() throws {
    let sections = ["Background", "Goals", "Playstyle", "Patience", "What you notice", "When you quit"]
    for slug in personaSlugs {
        let (_, body) = try agent(slug)
        for section in sections {
            #expect(body.contains("\n## \(section)\n"), "\(slug) has no \(section) section")
        }
        #expect(body.contains("playtest"), "\(slug) loads the playtest skill")
        #expect(body.contains("verify"), "\(slug) loads the verify skill")
    }
}

@Test("scenario: personas forbid desktop control")
func scenarioPersonasForbidDesktopControl() throws {
    for slug in allAgentSlugs {
        let (fields, body) = try agent(slug)
        #expect(body.contains("computer use"), "\(slug) forbids computer use")
        #expect(body.contains("desktop screen control"), "\(slug) forbids desktop screen control")
        #expect(!(fields["tools"] ?? "").contains("computer-use"), "\(slug) must not hold computer-use tools")
    }
}

@Test("scenario: personas set a minimum session")
func scenarioPersonasSetAMinimumSession() throws {
    for slug in personaSlugs {
        let (_, body) = try agent(slug)
        #expect(body.contains("30 minutes"), "\(slug) names the minimum session")
        #expect(body.contains("quit"), "\(slug) has a quit rule")
    }
}

@Test("scenario: each persona names its device")
func scenarioEachPersonaNamesItsDevice() throws {
    for (slug, needles) in deviceMatrix {
        let (_, body) = try agent(slug)
        let device = body.components(separatedBy: "\n## Device\n").dropFirst().first?
            .components(separatedBy: "\n## ").first ?? ""
        for needle in needles {
            #expect(device.contains(needle), "\(slug)'s Device section should name \(needle)")
        }
    }
}

@Test("scenario: the skill states the one-simulator rule")
func scenarioTheSkillStatesTheOneSimulatorRule() throws {
    let skill = try text(of: ".claude/skills/playtest/SKILL.md")
    #expect(skill.contains("simctl list devices booted"))
    #expect(skill.contains("simctl shutdown"))
    #expect(skill.contains("one simulator"))
}

@Test("scenario: the skill covers the session")
func scenarioTheSkillCoversTheSession() throws {
    let skill = try text(of: ".claude/skills/playtest/SKILL.md")
    for section in [
        "Start a session", "One simulator at a time", "Read the screen", "Launch flags", "Platform limits", "Reports"
    ] {
        #expect(skill.contains("\n## \(section)\n"), "the skill has no \(section) section")
    }
}

@Test("scenario: flags in the skill exist")
func scenarioFlagsInTheSkillExist() throws {
    var sources = ""
    for dir in ["Apps", "Packages/CityUI/Sources", "Packages/CityRender2D/Sources", "Packages/CityPersistence/Sources"] {
        let root = repoRoot.appendingPathComponent(dir)
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?.allObjects ?? []
        for case let url as URL in files where url.pathExtension == "swift" {
            sources += (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        }
    }
    var documents = try [text(of: ".claude/skills/playtest/SKILL.md")]
    for slug in allAgentSlugs {
        try documents.append(agent(slug).body)
    }
    let flags = Set(documents.flatMap { $0.matches(of: /-uiTest[A-Za-z]+/).map { String($0.output) } })
    #expect(!flags.isEmpty)
    for flag in flags {
        #expect(sources.contains("\"\(flag)\""), "\(flag) is not an app launch flag")
    }
}

@Test("scenario: the skill defines the report sections")
func scenarioTheSkillDefinesTheReportSections() throws {
    let skill = try text(of: ".claude/skills/playtest/SKILL.md")
    for section in [
        "Setup", "Timeline", "What was fun", "Confusing or frustrating", "Bugs", "Balance", "Top 3 changes",
        "Fun rating"
    ] {
        #expect(skill.contains("## \(section)"), "the report format has no \(section) section")
    }
    #expect(skill.contains("playtests/<date>-<persona>-<seed>.md"))
    #expect(skill.contains("playtests/<date>-<persona>/"))
}

@Test("scenario: the auditor covers the device matrix")
func scenarioTheAuditorCoversTheDeviceMatrix() throws {
    let (_, body) = try agent("ui-auditor")
    for device in ["iPhone SE", "iPhone 17", "iPhone 17 Pro Max", "iPad Pro 11-inch", "Apple TV", "Mac"] {
        #expect(body.contains(device), "the auditor skips \(device)")
    }
    #expect(body.contains("portrait") && body.contains("landscape"))
}

@Test("scenario: the auditor carries the checklist")
func scenarioTheAuditorCarriesTheChecklist() throws {
    let (_, body) = try agent("ui-auditor")
    for item in [
        "Tap targets", "Legibility", "Safe areas", "Overlap", "Dynamic Type", "Reflow", "Dark and light",
        "VoiceOver", "Focus order", "Pointer"
    ] {
        #expect(body.contains(item), "the checklist has no \(item) item")
    }
    for field in ["severity", "screenshot", "exact screen"] {
        #expect(body.localizedCaseInsensitiveContains(field), "each problem needs a \(field)")
    }
}

@Test("scenario: the skill records the platform limits")
func scenarioTheSkillRecordsThePlatformLimits() throws {
    let skill = try text(of: ".claude/skills/playtest/SKILL.md")
    #expect(skill.contains("press_key"))
    #expect(skill.contains("screencapture -x -o -l"))
    #expect(skill.contains("not exercised by hand"))
}
