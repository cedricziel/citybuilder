import Foundation
import Testing
@testable import CityAudio

// Tests for spec `audio-playback` — `Music shuffle policy` requirement.

@Test("scenario: single track loops with default gap")
func scenarioSingleTrackLoopsWithDefaultGap() {
    let playlist = MusicPlaylist(tracks: [Bindings.MusicTrack(file: "music/bards-tale.m4a")])
    // Every call to nextTrack() returns the same single track — the gap
    // is enforced by the caller waiting `gapSecondsBetweenTracks` between
    // plays.
    #expect(playlist.nextTrack()?.file == "music/bards-tale.m4a")
    #expect(playlist.nextTrack()?.file == "music/bards-tale.m4a")
    #expect(playlist.nextTrack()?.file == "music/bards-tale.m4a")
    #expect(playlist.gapSecondsBetweenTracks == 30.0)
}

@Test("scenario: three tracks avoid recent repeats")
func scenarioThreeTracksAvoidRecentRepeats() {
    let playlist = MusicPlaylist(tracks: [
        Bindings.MusicTrack(file: "a.m4a"),
        Bindings.MusicTrack(file: "b.m4a"),
        Bindings.MusicTrack(file: "c.m4a")
    ])
    var picks: [String] = []
    for _ in 0 ..< 30 {
        guard let track = playlist.nextTrack() else {
            Issue.record("playlist exhausted unexpectedly")
            return
        }
        picks.append(track.file)
    }
    // No track appears twice within any 3-pick window.
    for index in 0 ..< (picks.count - 2) {
        let window = Set(picks[index ... index + 2])
        #expect(window.count == 3, "window starting at \(index) has duplicates: \(Array(picks[index ... index + 2]))")
    }
}

@Test("playlist: empty returns nil")
func playlistEmptyReturnsNil() {
    let playlist = MusicPlaylist(tracks: [])
    #expect(playlist.nextTrack() == nil)
}

@Test("playlist: custom gap honoured")
func playlistCustomGapHonoured() {
    let playlist = MusicPlaylist(
        tracks: [Bindings.MusicTrack(file: "x.m4a")],
        gapSecondsBetweenTracks: 10.0
    )
    #expect(playlist.gapSecondsBetweenTracks == 10.0)
}
