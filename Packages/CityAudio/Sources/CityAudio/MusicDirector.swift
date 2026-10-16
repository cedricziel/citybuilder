import CityCore

/// Chooses the music: the title theme on the menu, shuffled pieces with a
/// gap between them in a game, leaning toward the season's mood, and a
/// crossfade whenever the context changes. Driven by wall-clock `tick`s.
/// Spec: `audio-playback` / Music follows the title screen, the game and
/// the season.
@MainActor
public final class MusicDirector {
    public enum Context: Equatable, Sendable {
        case title, game
    }

    static let defaultCrossfade = 3.0
    /// Assumed length of a track whose file can't be read.
    static let fallbackDuration = 180.0

    private let title: Bindings.MusicTrack?
    private let playlist: MusicPlaylist
    private let crossfade: Double
    /// Starts a track: its path, fade-in seconds, and whether it loops.
    private let play: (String, Double, Bool) -> Void
    private let fadeOut: (String, Double) -> Void
    private let duration: (String) -> Double?

    private var context = Context.title
    private(set) var season: Season?
    private var switching = false
    private var clock = 0.0
    private var current: (path: String, endsAt: Double)?
    private var nextStartAt: Double? = 0

    init(
        section: Bindings.MusicSection?,
        rng: any RandomNumberGenerator = SystemRandomNumberGenerator(),
        play: @escaping (String, Double, Bool) -> Void,
        fadeOut: @escaping (String, Double) -> Void,
        duration: @escaping (String) -> Double?
    ) {
        title = section?.title
        playlist = MusicPlaylist(
            tracks: section?.tracks ?? [],
            gapSecondsBetweenTracks: section?.gapSecondsBetweenTracks ?? MusicPlaylist.defaultGapSeconds,
            rng: rng
        )
        crossfade = section?.crossfadeSeconds ?? Self.defaultCrossfade
        self.play = play
        self.fadeOut = fadeOut
        self.duration = duration
    }

    /// Switches between the title and a game. Leaving a game forgets its
    /// season, so the next game's first pick follows its own season.
    public func setContext(_ newContext: Context) {
        guard newContext != context else { return }
        context = newContext
        if newContext == .title { season = nil }
        switching = true
    }

    public func setSeason(_ newSeason: Season?) {
        season = newSeason
    }

    public func tick(dt: Double) {
        clock += dt
        if switching {
            switching = false
            if let playing = current {
                fadeOut(playing.path, crossfade)
                current = nil
            }
            start(fade: crossfade)
            return
        }
        if let playing = current, clock >= playing.endsAt {
            current = nil
            nextStartAt = clock + (repeatsTitle ? 0 : playlist.gapSecondsBetweenTracks)
        }
        if current == nil, let startAt = nextStartAt, clock >= startAt {
            start(fade: 0)
        }
    }

    /// The title theme repeats back to back; game tracks wait out the gap.
    private var repeatsTitle: Bool {
        context == .title && title != nil
    }

    private func start(fade: Double) {
        let track = repeatsTitle ? title : playlist.nextTrack { [season] in $0.suits(season) }
        guard let path = track?.file else {
            nextStartAt = nil
            return
        }
        // The title theme loops in the player, gaplessly; game tracks play once.
        let loops = repeatsTitle
        play(path, fade, loops)
        current = (path, loops ? .infinity : clock + (duration(path) ?? Self.fallbackDuration))
        nextStartAt = nil
    }
}
