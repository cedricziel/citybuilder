import CityCore
import Foundation
import Testing
@testable import CityAudio

// Spec `audio-playback`: "Music follows the title screen, the game and the season".

@MainActor
private final class Recorder {
    var log: [String] = []
    var durations: [String: Double] = [:]

    func director(_ section: Bindings.MusicSection) -> MusicDirector {
        MusicDirector(
            section: section,
            play: { [unowned self] path, fade, loops in log.append("play \(path) \(fade)\(loops ? " loop" : "")") },
            fadeOut: { [unowned self] path, fade in log.append("fade \(path) \(fade)") },
            duration: { [unowned self] path in durations[path] }
        )
    }
}

private func section(
    title: String? = "music/title.caf",
    tracks: [Bindings.MusicTrack] = [Bindings.MusicTrack(file: "music/a.caf")]
) -> Bindings.MusicSection {
    Bindings.MusicSection(tracks: tracks, gapSecondsBetweenTracks: 30, title: title.map { Bindings.MusicTrack(file: $0) })
}

@MainActor
private func run(_ director: MusicDirector, seconds: Double) {
    for _ in 0 ..< Int((seconds * 10).rounded()) {
        director.tick(dt: 0.1)
    }
}

@MainActor
@Test("scenario: the title theme plays on the menu")
func titleThemePlaysOnTheMenu() {
    let recorder = Recorder()
    recorder.durations = ["music/title.caf": 20]
    let director = recorder.director(section())
    director.tick(dt: 0.1)
    #expect(recorder.log == ["play music/title.caf 0.0 loop"])
    run(director, seconds: 60)
    #expect(recorder.log.count == 1, "the player loops the title; the director never restarts it")
}

@MainActor
@Test("scenario: starting a game crossfades to game music")
func startingAGameCrossfades() {
    let recorder = Recorder()
    recorder.durations = ["music/title.caf": 20, "music/a.caf": 60]
    let director = recorder.director(section())
    director.tick(dt: 0.1)
    director.setContext(.game)
    director.tick(dt: 0.1)
    #expect(Array(recorder.log.suffix(2)) == ["fade music/title.caf 3.0", "play music/a.caf 3.0"])
}

@MainActor
@Test("scenario: game tracks are separated by the gap")
func gameTracksAreSeparatedByTheGap() {
    let recorder = Recorder()
    recorder.durations = ["music/a.caf": 60]
    let director = recorder.director(section(title: nil))
    director.setContext(.game)
    director.tick(dt: 0.1)
    #expect(recorder.log == ["play music/a.caf 3.0"])
    run(director, seconds: 60 + 29)
    #expect(recorder.log.count == 1)
    run(director, seconds: 1.5)
    #expect(recorder.log.count == 2)
}

@MainActor
@Test("scenario: the season leans the choice")
func seasonLeansTheChoice() {
    let recorder = Recorder()
    let tracks = [
        Bindings.MusicTrack(file: "music/winter.caf", seasons: ["winter"]),
        Bindings.MusicTrack(file: "music/summer.caf", seasons: ["summer"]),
        Bindings.MusicTrack(file: "music/any.caf")
    ]
    recorder.durations = ["music/winter.caf": 1, "music/summer.caf": 1, "music/any.caf": 1]
    let director = recorder.director(Bindings.MusicSection(tracks: tracks, gapSecondsBetweenTracks: 0))
    director.setContext(.game)
    director.setSeason(.winter)
    run(director, seconds: 60)
    #expect(!recorder.log.isEmpty)
    #expect(!recorder.log.contains { $0.contains("summer") })
}

@MainActor
@Test("scenario: returning to the title brings back its theme")
func returningToTheTitle() {
    let recorder = Recorder()
    recorder.durations = ["music/title.caf": 20, "music/a.caf": 60]
    let director = recorder.director(section())
    director.setContext(.game)
    director.tick(dt: 0.1)
    run(director, seconds: 10)
    director.setContext(.title)
    director.tick(dt: 0.1)
    #expect(Array(recorder.log.suffix(2)) == ["fade music/a.caf 3.0", "play music/title.caf 3.0 loop"])
}

@MainActor
@Test func noMusicPlaysNothing() {
    let recorder = Recorder()
    let director = recorder.director(Bindings.MusicSection())
    run(director, seconds: 5)
    director.setContext(.game)
    run(director, seconds: 5)
    #expect(recorder.log.isEmpty)
}

@MainActor
@Test("scenario: game, title and game again")
func gameTitleGameToggle() {
    let recorder = Recorder()
    recorder.durations = ["music/title.caf": 20, "music/a.caf": 60]
    let director = recorder.director(section())
    director.tick(dt: 0.1)
    director.setContext(.game)
    director.tick(dt: 0.1)
    director.setContext(.title)
    director.tick(dt: 0.1)
    director.setContext(.game)
    director.tick(dt: 0.1)
    #expect(recorder.log == [
        "play music/title.caf 0.0 loop",
        "fade music/title.caf 3.0", "play music/a.caf 3.0",
        "fade music/a.caf 3.0", "play music/title.caf 3.0 loop",
        "fade music/title.caf 3.0", "play music/a.caf 3.0"
    ])
}

@MainActor
@Test("scenario: a new game starts without the last game's season")
func newGameForgetsTheLastSeason() {
    let recorder = Recorder()
    let tracks = [
        Bindings.MusicTrack(file: "music/winter.caf", seasons: ["winter"]),
        Bindings.MusicTrack(file: "music/summer.caf", seasons: ["summer"])
    ]
    recorder.durations = ["music/winter.caf": 100, "music/summer.caf": 100]
    let director = recorder.director(Bindings.MusicSection(tracks: tracks))
    director.setContext(.game)
    director.setSeason(.winter)
    director.tick(dt: 0.1)
    director.setContext(.title)
    director.tick(dt: 0.1)
    #expect(director.season == nil)
}

@MainActor
@Test("scenario: the title theme loops without a restart")
func titleThemeLoopsWithoutARestart() {
    let recorder = Recorder()
    recorder.durations = ["music/title.caf": 20]
    let director = recorder.director(section())
    run(director, seconds: 60)
    #expect(recorder.log == ["play music/title.caf 0.0 loop"])
}
