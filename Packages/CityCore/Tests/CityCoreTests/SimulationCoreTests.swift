import Foundation
import Testing
@testable import CityCore

// Tests for spec `simulation-core` — every `#### Scenario:` heading from
// openspec/changes/add-mvp-foundation/specs/simulation-core/spec.md maps to
// at least one `@Test("scenario: <lowercased title>")` here.

// MARK: - Framework-free invariant

@Test("scenario: core compiles on Linux toolchain")
func scenarioCoreCompilesOnLinuxToolchain() {
    // This is a build-time invariant: CityCore must not import any Apple
    // UI framework. It is mechanically enforced by
    // scripts/check-no-apple-ui-imports.sh, which CI and pre-commit run.
    //
    // At runtime we can only assert that the module loaded successfully
    // (which happens just by virtue of this test executing) and that the
    // version symbol is present and stable.
    #expect(!CityCore.version.isEmpty)
}

// MARK: - Tick model

@Test("scenario: tick is fixed duration")
func scenarioTickIsFixedDuration() {
    var world = World(seed: 42)
    let before = world.simulatedTime
    world.tick()
    let after = world.simulatedTime
    #expect(after - before == .milliseconds(100), "tick must advance simulated time by exactly 100 ms")
}

@Test("scenario: determinism under replay")
func scenarioDeterminismUnderReplay() {
    var worldA = World.fixtureWithTerrain(width: 8, height: 8, fill: .forest, seed: 1234)
    var worldB = World.fixtureWithTerrain(width: 8, height: 8, fill: .forest, seed: 1234)
    let commands: [Command] = [
        .noop,
        .harvestForest(at: TileCoordinate(x: 2, y: 3)),
        .noop,
        .harvestForest(at: TileCoordinate(x: 5, y: 5))
    ]
    for command in commands {
        worldA.enqueue(command)
        worldB.enqueue(command)
    }
    for _ in 0 ..< 50 {
        worldA.tick()
        worldB.tick()
    }
    #expect(worldA == worldB, "identical seeds + commands must yield equal worlds after N ticks")
}

// MARK: - RNG

@Test("scenario: RNG seed persists across save/load")
func scenarioRngSeedPersistsAcrossSaveLoad() throws {
    var world = World(seed: 7777)
    for _ in 0 ..< 10 {
        _ = world.rng.next()
    }
    let nextBeforeSave = world.rng

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let encoded = try encoder.encode(world)
    var loaded = try decoder.decode(World.self, from: encoded)

    let draw1Before = nextBeforeSave
    var draw1Replay = nextBeforeSave
    let predicted = draw1Replay.next()
    let actual = loaded.rng.next()
    #expect(actual == predicted, "RNG sequence must continue identically after save/load")
    _ = draw1Before
}

// MARK: - Commands

@Test("scenario: command applied at next tick")
func scenarioCommandAppliedAtNextTick() {
    var world = World.fixtureWithTerrain(width: 8, height: 8, fill: .forest, seed: 1)
    let target = TileCoordinate(x: 3, y: 3)
    #expect(world.terrain(at: target) == .forest)

    world.enqueue(.harvestForest(at: target))
    // Mid-tick: command not yet applied.
    #expect(world.terrain(at: target) == .forest, "command effects must not be visible before tick boundary")

    world.tick()
    #expect(world.terrain(at: target) == .grass, "command effects must be observable starting at tick T+1")
}

// MARK: - ECS

@Test("scenario: entity is opaque ID")
func scenarioEntityIsOpaqueID() {
    let entity = EntityID(raw: 17)
    #expect(entity.raw == 17)
    let mirror = Mirror(reflecting: entity)
    // The struct exposes exactly one stored property: the raw integer.
    let storedProperties = mirror.children.compactMap(\.label)
    #expect(storedProperties == ["raw"], "EntityID must remain an opaque integer ID with no extra fields")
}

// MARK: - Snapshotting

@Test("scenario: save/load round-trip")
func scenarioSaveLoadRoundTrip() throws {
    let original = World.fixtureWithTerrain(width: 12, height: 12, fill: .grass, seed: 999)
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let encoded = try encoder.encode(original)
    let decoded = try decoder.decode(World.self, from: encoded)
    #expect(decoded == original, "Codable round-trip must preserve world state exactly")
}

// MARK: - Performance / instrumentation

@Test("scenario: tick time instrumented")
func scenarioTickTimeInstrumented() {
    var world = World.fixtureWithTerrain(width: 4, height: 4, fill: .grass, seed: 1)
    let result = world.tick()
    // wallClockNanoseconds is UInt64 — non-negative by type. Asserting
    // that we got a value back is the contract: tick must surface
    // measurable wall-clock cost via a metrics interface.
    #expect(result.metrics.wallClockNanoseconds < 1_000_000_000, "stub tick must complete in under one second")
}

// MARK: - TickResult aggregate (add-audio-foundation M1)

@Test("scenario: tick returns tickresult")
func scenarioTickReturnsTickResult() {
    var world = World.fixtureWithTerrain(width: 4, height: 4, fill: .grass, seed: 1)
    let result: World.TickResult = world.tick()
    // .metrics carries the existing wall-clock instrumentation.
    _ = result.metrics
    // .events is an immutable [WorldEvent]; empty until M2/M4 emission lands.
    #expect(result.events.isEmpty)
}

@Test("scenario: tickmetrics still observable")
func scenarioTickMetricsStillObservable() {
    var world = World.fixtureWithTerrain(width: 4, height: 4, fill: .grass, seed: 1)
    let result = world.tick()
    // The exact accessor existing callers had — just nested one level deeper.
    #expect(result.metrics.wallClockNanoseconds < 1_000_000_000)
}

// MARK: - Headless CLI

@Test("scenario: cli runner steps simulation")
func scenarioCliRunnerStepsSimulation() throws {
    // citybuilder-cli accepts `--save FILE --ticks N` and writes a summary
    // without launching any Apple UI framework. We exercise the function
    // that backs the CLI rather than spawning a subprocess so the test
    // stays headless.
    let summary = try HeadlessRunner.run(
        loadFrom: nil, // nil = fresh world from the default fixture
        ticks: 25
    )
    #expect(summary.tickCount == 25)
    #expect(summary.simulatedTime == .milliseconds(2500))
}

// MARK: - CLI event log dump (add-audio-foundation M5)

@Test("scenario: cli writes event log when requested")
func scenarioCliWritesEventLogWhenRequested() throws {
    // The CLI's `--events-out FILE` flag uses `runCollectingEvents` to
    // accumulate every WorldEvent emitted across N ticks. We exercise
    // that overload directly (subprocess invocation of the built CLI
    // binary is out of scope for the swift-test target).
    let saveURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("audio-cli-test-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: saveURL) }

    var seed = World.fixtureWithTerrain(width: 6, height: 6, fill: .grass, seed: 1)
    seed.enqueue(.place(.road, at: TileCoordinate(x: 1, y: 1)))
    try JSONEncoder().encode(seed).write(to: saveURL)

    let (summary, events) = try HeadlessRunner.runCollectingEvents(
        loadFrom: saveURL.path,
        ticks: 5
    )
    #expect(summary.tickCount == 5)
    // Tick 1 applies the queued place and the road completes construction
    // (road buildDurationTicks=1) — at minimum we get a buildingPlaced and
    // a constructionCompleted event in the log.
    let hasPlacement = events.contains(where: {
        if case .buildingPlaced = $0 { return true }
        return false
    })
    let hasCompletion = events.contains(where: {
        if case .constructionCompleted = $0 { return true }
        return false
    })
    #expect(hasPlacement, "events log should include the queued road placement")
    #expect(hasCompletion, "road completes in one tick — completion event must be present")
}

@Test("scenario: cli omits event log by default")
func scenarioCliOmitsEventLogByDefault() throws {
    // Without --events-out, the CLI calls plain `HeadlessRunner.run`, which
    // returns a `Summary` that carries no events field. The default run
    // path therefore does not surface events to the caller at all.
    let summary = try HeadlessRunner.run(loadFrom: nil, ticks: 5)
    let mirror = Mirror(reflecting: summary)
    let hasEventsField = mirror.children.contains(where: { $0.label == "events" })
    #expect(!hasEventsField, "default run path must not expose events on Summary")
}
