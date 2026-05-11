import Foundation

/// Picks the next music track to play. Per spec `audio-playback`
/// "Music shuffle policy".
///
/// With a single bound track, every `nextTrack()` returns that track and
/// the caller waits `gapSecondsBetweenTracks` before calling again. With
/// multiple tracks, a "no-repeat-within-last-two" shuffle keeps the
/// playlist from feeling repetitive.
public final class MusicPlaylist: @unchecked Sendable {
    public let tracks: [Bindings.MusicTrack]
    public let gapSecondsBetweenTracks: Double
    private var rng: any RandomNumberGenerator
    private var lastPicks: [Int] = []

    /// Default gap (seconds) between consecutive plays when only one track
    /// is bound. Long enough that the player isn't a continuous wash; short
    /// enough that quiet stretches don't feel forgotten.
    public static let defaultGapSeconds: Double = 30.0

    public init(
        tracks: [Bindings.MusicTrack],
        gapSecondsBetweenTracks: Double = MusicPlaylist.defaultGapSeconds,
        rng: any RandomNumberGenerator = SystemRandomNumberGenerator()
    ) {
        self.tracks = tracks
        self.gapSecondsBetweenTracks = gapSecondsBetweenTracks
        self.rng = rng
    }

    /// Returns the next track to play, or nil if the playlist is empty.
    public func nextTrack() -> Bindings.MusicTrack? {
        guard !tracks.isEmpty else { return nil }
        if tracks.count == 1 {
            return tracks[0]
        }
        // No-repeat-within-last-two: avoid indices that appear in the
        // last two picks. Fall back to all indices if the constraint
        // would leave no candidates (only possible when tracks.count < 3
        // — handled separately above for the count == 1 case).
        let recent = Set(lastPicks.suffix(2))
        var candidates = tracks.indices.filter { !recent.contains($0) }
        if candidates.isEmpty {
            candidates = Array(tracks.indices)
        }
        let pick = candidates.randomElement(using: &rng) ?? 0
        lastPicks.append(pick)
        return tracks[pick]
    }
}
