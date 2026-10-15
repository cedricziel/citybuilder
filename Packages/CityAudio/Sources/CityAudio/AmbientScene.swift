import CityCore

/// Mixes the ambient beds by context: the current season's bed, softened
/// near the sea, and the coastal bed swelling with the share of water
/// around the listener. Gains glide toward their targets a step per tick,
/// so beds crossfade. Spec: `audio-playback` / Ambient beds follow season
/// and shore.
@MainActor
public final class AmbientScene {
    static let radius = 6
    static let step: Float = 0.025

    private let seasons: [Season: String]
    private let coast: String?
    private let start: (String) -> Void
    private let setGain: (String, Float) -> Void
    private let stop: (String) -> Void

    private var season: Season?
    private var seaShare = 0.0
    private var listener: TileCoordinate?
    private var snapshot: WorldSnapshot?
    private(set) var gains: [String: Float] = [:]

    init(
        seasons: [Season: String],
        coast: String?,
        start: @escaping (String) -> Void,
        setGain: @escaping (String, Float) -> Void,
        stop: @escaping (String) -> Void
    ) {
        self.seasons = seasons
        self.coast = coast
        self.start = start
        self.setGain = setGain
        self.stop = stop
    }

    /// The scene for a bindings section that names seasonal beds, playing
    /// through `player`; nil for a section without them.
    convenience init?(section: Bindings.AmbientSection?, player: EngineCuePlayer) {
        let seasons = section?.seasonFiles ?? [:]
        guard !seasons.isEmpty else { return nil }
        self.init(
            seasons: seasons,
            coast: section?.coast,
            start: { [weak player] path in
                let cue = Bindings.Cue(file: path, bus: .ambient, volume: 0, loop: true, spatialize: false)
                player?.play(DispatchedCue(cue: cue))
            },
            setGain: { [weak player] path, gain in player?.setLoopVolume(path: path, volume: gain) },
            stop: { [weak player] path in player?.stopLoop(path: path) }
        )
    }

    /// The gain each bed is gliding toward; empty until a snapshot arrives.
    var targets: [String: Float] {
        guard let season else { return [:] }
        var targets: [String: Float] = [:]
        for (each, path) in seasons {
            targets[path] = each == season ? Float(1 - seaShare / 2) : 0
        }
        if let coast {
            targets[coast] = Float(min(1, seaShare * 1.5))
        }
        return targets
    }

    public func consumeSnapshot(_ snapshot: WorldSnapshot) {
        let first = self.snapshot == nil
        self.snapshot = snapshot
        season = snapshot.date.season
        if first { updateSeaShare() }
    }

    public func setListener(_ tile: TileCoordinate?) {
        guard tile != listener else { return }
        listener = tile
        updateSeaShare()
    }

    /// Moves every gain one step toward its target, starting and stopping beds.
    public func tick() {
        for (path, target) in targets {
            let current = gains[path]
            if current == nil {
                guard target > 0 else { continue }
                start(path)
            }
            let from = current ?? 0
            // Snap within a step (plus rounding slack) so 40 steps of 0.025 land on 1.
            let next = abs(target - from) <= Self.step * 1.001 ? target
                : from + (target > from ? Self.step : -Self.step)
            if next <= 0, target <= 0 {
                gains[path] = nil
                stop(path)
            } else if next != current {
                gains[path] = next
                setGain(path, next)
            }
        }
    }

    private func updateSeaShare() {
        guard let snapshot, let listener else { return }
        seaShare = Self.seaShare(in: snapshot, around: listener)
    }

    /// The share of on-map tiles within `radius` of `tile` that are water.
    static func seaShare(in snapshot: WorldSnapshot, around tile: TileCoordinate, radius: Int = radius) -> Double {
        var water = 0
        var total = 0
        for y in (tile.y - radius) ... (tile.y + radius) {
            for x in (tile.x - radius) ... (tile.x + radius) {
                guard let terrain = snapshot.terrain(at: TileCoordinate(x: x, y: y)) else { continue }
                total += 1
                if terrain == .water { water += 1 }
            }
        }
        return total == 0 ? 0 : Double(water) / Double(total)
    }
}
