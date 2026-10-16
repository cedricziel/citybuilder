import CityCore
import Foundation
import Testing
@testable import CityAudio

// Spec `audio-playback`: "Ambient beds follow season and shore".

private let seasons: [Season: String] = [
    .spring: "ambient/spring.caf", .summer: "ambient/summer.caf",
    .autumn: "ambient/autumn.caf", .winter: "ambient/winter.caf"
]
private let coast = "ambient/coast.caf"

/// A 20×20 map: land in the west half (x < 10), sea in the east.
private func snapshot(_ season: Season) -> WorldSnapshot {
    let grid = (0 ..< 400).map { $0 % 20 < 10 ? TerrainType.grass : .water }
    return WorldSnapshot(
        tickCount: 0, simulatedTime: .zero, mapWidth: 20, mapHeight: 20, terrainGrid: grid, occupiedTiles: [:],
        buildings: [:], carriers: [], economy: Economy(), totalPopulation: 0, camera: Camera(),
        date: GameDate(year: 1200, season: season)
    )
}

@MainActor
private final class Engine {
    var playing: [String: Float] = [:]
    var started: [String] = []
    var stopped: [String] = []
    lazy var scene = AmbientScene(
        seasons: seasons,
        coast: coast,
        start: { [unowned self] path in started.append(path); playing[path] = 0 },
        setGain: { [unowned self] path, gain in playing[path] = gain },
        stop: { [unowned self] path in stopped.append(path); playing[path] = nil }
    )

    /// `count` tenths of a second of wall-clock time, as the audio timer ticks.
    func tick(_ count: Int) {
        for _ in 0 ..< count {
            scene.tick(dt: 0.1)
        }
    }
}

@MainActor
@Test("scenario: seasons crossfade")
func seasonsCrossfade() {
    let engine = Engine()
    engine.scene.setListener(TileCoordinate(x: 2, y: 10))
    engine.scene.consumeSnapshot(snapshot(.autumn))
    engine.tick(40)
    #expect(engine.playing == ["ambient/autumn.caf": 1], "\(engine.playing)")
    engine.scene.consumeSnapshot(snapshot(.winter))
    engine.tick(20)
    #expect(abs((engine.playing["ambient/autumn.caf"] ?? -1) - 0.5) < 1e-4)
    #expect(abs((engine.playing["ambient/winter.caf"] ?? -1) - 0.5) < 1e-4)
    engine.tick(20)
    #expect(engine.stopped == ["ambient/autumn.caf"])
    #expect(engine.playing == ["ambient/winter.caf": 1])
}

@MainActor
@Test("scenario: the shore brings in the surf")
func shoreBringsInTheSurf() {
    let engine = Engine()
    engine.scene.consumeSnapshot(snapshot(.summer))
    engine.scene.setListener(TileCoordinate(x: 10, y: 10))
    let share = AmbientScene.seaShare(in: snapshot(.summer), around: TileCoordinate(x: 10, y: 10))
    #expect(abs(share - 0.5) < 0.05)
    let targets = engine.scene.targets
    #expect(abs((targets[coast] ?? 0) - Float(min(1, share * 1.5))) < 1e-6)
    #expect(abs((targets["ambient/summer.caf"] ?? 0) - Float(1 - share / 2)) < 1e-6)
}

@MainActor
@Test("scenario: ambience waits for the world")
func ambienceWaitsForTheWorld() {
    let engine = Engine()
    engine.scene.setListener(TileCoordinate(x: 2, y: 2))
    engine.tick(50)
    #expect(engine.started.isEmpty)
}

@Test func seasonalSectionDecodes() throws {
    let json = #"{"tracks":[],"seasons":{"winter":"ambient/winter.caf"},"coast":"ambient/coast.caf"}"#
    let section = try JSONDecoder().decode(Bindings.AmbientSection.self, from: Data(json.utf8))
    #expect(section.seasonFiles == [.winter: "ambient/winter.caf"])
    #expect(section.coast == "ambient/coast.caf")
}

@MainActor
@Test("scenario: crossfades keep their pace at any game speed")
func crossfadesKeepTheirPace() {
    for snapshotsPerTick in [0, 1, 3] { // paused, 1×, 3×
        let engine = Engine()
        engine.scene.setListener(TileCoordinate(x: 2, y: 10))
        engine.scene.consumeSnapshot(snapshot(.autumn))
        engine.tick(40)
        engine.scene.consumeSnapshot(snapshot(.winter))
        for _ in 0 ..< 20 {
            for _ in 0 ..< snapshotsPerTick {
                engine.scene.consumeSnapshot(snapshot(.winter))
            }
            engine.tick(1)
        }
        #expect(abs((engine.playing["ambient/winter.caf"] ?? -1) - 0.5) < 1e-4, "\(snapshotsPerTick) snapshots a tick")
    }
}

@MainActor
@Test("scenario: session end stops the beds")
func sessionEndStopsTheBeds() {
    let engine = Engine()
    engine.scene.setListener(TileCoordinate(x: 10, y: 10))
    engine.scene.consumeSnapshot(snapshot(.summer))
    engine.tick(10)
    #expect(Set(engine.playing.keys) == ["ambient/summer.caf", coast])
    engine.scene.endSession()
    #expect(engine.playing.isEmpty)
    #expect(engine.scene.gains.isEmpty)
    engine.tick(10)
    #expect(engine.playing.isEmpty, "nothing restarts until the next game's snapshot")
}

@MainActor
@Test func noListenerMeansInland() {
    let engine = Engine()
    engine.scene.consumeSnapshot(snapshot(.summer))
    engine.scene.setListener(TileCoordinate(x: 12, y: 10))
    #expect((engine.scene.targets[coast] ?? 0) > 0)
    engine.scene.setListener(nil)
    #expect(engine.scene.targets[coast] == 0)
    #expect(engine.scene.targets["ambient/summer.caf"] == 1)
}

@Test func shippedBindingsNameEverySeasonAndTheCoast() throws {
    let audio = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources/Audio")
    let manifest = try Manifest.load(from: Data(contentsOf: audio.appendingPathComponent("manifest.json")))
    let bindings = try Bindings.load(from: Data(contentsOf: audio.appendingPathComponent("bindings.json")), manifest: manifest)
    let section = try #require(bindings.ambient)
    #expect(Set(section.seasonFiles.keys) == Set(Season.allCases))
    #expect(section.coast != nil)
}
