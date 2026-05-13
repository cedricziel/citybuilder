import AVFoundation
import CityCore
import Foundation

/// Production `AudioCoordinator.CueDispatcher` implementation. Resolves
/// the cue's file path against a `Bundle`, loads it as an `AVAudioFile`,
/// schedules playback on the appropriate bus, and (for loop cues) tracks
/// the player by source so a future `stopLoop` call can halt it.
///
/// Errors during file load or scheduling are logged and swallowed — the
/// audio layer is non-fatal by design (spec `audio-playback` "Missing
/// audio file is silent, not fatal").
@MainActor
public final class EngineCuePlayer {
    private let engine: AudioEngine
    private let bundle: Bundle
    /// Caches loaded `AVAudioFile`s by relative path so the second hit for
    /// the same cue doesn't re-read the file off disk.
    private var fileCache: [String: AVAudioFile] = [:]
    /// One-shot player nodes are pooled for reuse — we attach a small set
    /// upfront and round-robin through them.
    private var oneShotPool: [AudioBus: [AVAudioPlayerNode]] = [:]
    private var nextPoolIndex: [AudioBus: Int] = [:]
    /// Active loop player nodes keyed by the source path. The
    /// `AudioCoordinator` carries the entity → cue mapping; this layer
    /// only needs the path to stop the right player.
    private var loopPlayers: [String: AVAudioPlayerNode] = [:]

    public init(engine: AudioEngine, bundle: Bundle = .main, oneShotPoolSize: Int = 4) {
        self.engine = engine
        self.bundle = bundle
        for bus in AudioBus.allCases {
            var nodes: [AVAudioPlayerNode] = []
            for _ in 0 ..< oneShotPoolSize {
                let node = AVAudioPlayerNode()
                nodes.append(node)
            }
            oneShotPool[bus] = nodes
            nextPoolIndex[bus] = 0
        }
    }

    /// Dispatches a cue: loads the file, schedules it on the cue's bus,
    /// and starts playback. No-op (with a logged warning) if the file is
    /// missing or the load fails.
    public func play(_ dispatched: DispatchedCue) {
        let cue = dispatched.cue
        guard let file = loadFile(at: cue.file) else { return }

        do {
            try engine.start()
        } catch {
            return
        }

        if cue.loop == true {
            playLoop(dispatched: dispatched, file: file)
        } else {
            playOneShot(cue: cue, file: file)
        }
    }

    /// Halts the loop player for `path`, if any.
    public func stopLoop(path: String) {
        guard let player = loopPlayers.removeValue(forKey: path) else { return }
        player.stop()
        // Detach so subsequent play() doesn't reuse a node that's mid-stop.
        engine.bus(.loop).engine?.detach(player)
    }

    private func playOneShot(cue: Bindings.Cue, file: AVAudioFile) {
        guard let player = nextOneShotPlayer(on: cue.bus) else { return }
        let mixer = engine.bus(cue.bus)
        if player.engine !== mixer.engine {
            mixer.engine?.attach(player)
            mixer.engine?.connect(player, to: mixer, format: file.processingFormat)
        }
        if let volume = cue.volume {
            player.volume = volume
        }
        player.stop()
        player.scheduleFile(file, at: nil, completionHandler: nil)
        player.play()
    }

    private func playLoop(dispatched: DispatchedCue, file: AVAudioFile) {
        let cue = dispatched.cue
        // Idempotent at this level too — if a loop is already playing for
        // this path, leave it alone. The coordinator also guards against
        // duplicate-start via its EntityID map.
        if loopPlayers[cue.file] != nil { return }
        let player = AVAudioPlayerNode()
        let routing = Self.loopRouting(for: dispatched, environmentAvailable: engine.environmentNode != nil)
        let target = node(for: routing.target, dispatched: dispatched)
        engine.underlyingEngine.attach(player)
        engine.underlyingEngine.connect(player, to: target, format: file.processingFormat)
        if let position = routing.position {
            player.position = position
        }
        if let volume = cue.volume {
            player.volume = volume
        }
        loopPlayers[cue.file] = player
        scheduleLooped(player: player, file: file, path: cue.file)
        player.play()
    }

    /// Where a loop cue should attach. `loopMixer` is the historical path
    /// (no 3D); `environmentNode` is the spatial path used when the cue
    /// opts in AND the engine has the environment node active.
    enum LoopRoutingTarget: Equatable {
        case loopMixer
        case environmentNode
    }

    struct LoopRouting: Equatable {
        let target: LoopRoutingTarget
        let position: AVAudio3DPoint?

        static func == (lhs: LoopRouting, rhs: LoopRouting) -> Bool {
            guard lhs.target == rhs.target else { return false }
            switch (lhs.position, rhs.position) {
            case (nil, nil): return true
            case let (lhsPos?, rhsPos?):
                return lhsPos.x == rhsPos.x && lhsPos.y == rhsPos.y && lhsPos.z == rhsPos.z
            default: return false
            }
        }
    }

    /// Pure routing decision for a loop cue. Exposed for testing.
    nonisolated static func loopRouting(
        for dispatched: DispatchedCue,
        environmentAvailable: Bool
    ) -> LoopRouting {
        // Spatial routing requires the cue to opt in (default: loop bus)
        // and the engine to have the environment node wired. Both must
        // hold; otherwise fall back to the loop mixer.
        let spatial = dispatched.isSpatialized && environmentAvailable
        guard spatial else {
            return LoopRouting(target: .loopMixer, position: nil)
        }
        if let tile = dispatched.position {
            return LoopRouting(
                target: .environmentNode,
                position: AVAudio3DPoint(x: Float(tile.x), y: 0, z: Float(tile.y))
            )
        }
        // Spatial routing was requested but no position was resolved —
        // fall back to the loop mixer; the env node would just see the
        // source at origin which is misleading.
        return LoopRouting(target: .loopMixer, position: nil)
    }

    private func node(for target: LoopRoutingTarget, dispatched: DispatchedCue) -> AVAudioNode {
        switch target {
        case .loopMixer:
            return engine.bus(dispatched.cue.bus)
        case .environmentNode:
            return engine.environmentNode ?? engine.bus(dispatched.cue.bus)
        }
    }

    private func scheduleLooped(player: AVAudioPlayerNode, file: AVAudioFile, path: String) {
        // Re-schedule on completion to achieve a continuous loop. Critically
        // we use `.dataPlayedBack` rather than the default `.dataConsumed` —
        // dataConsumed fires the moment the file is read into the player's
        // input buffer (within milliseconds for a small file), so a recursive
        // re-schedule would queue thousands of identical files within seconds.
        // dataPlayedBack fires only when the buffer is actually finished playing.
        //
        // We look the player back up by `path` rather than capturing the
        // AVAudioPlayerNode (which isn't Sendable). If `stopLoop(path:)` ran
        // before playback finished, the lookup returns nil and we don't
        // re-schedule — natural lifecycle.
        player.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard let current = self.loopPlayers[path] else { return }
                self.scheduleLooped(player: current, file: file, path: path)
            }
        }
    }

    private func nextOneShotPlayer(on bus: AudioBus) -> AVAudioPlayerNode? {
        guard var nodes = oneShotPool[bus], !nodes.isEmpty else { return nil }
        let index = nextPoolIndex[bus] ?? 0
        let player = nodes[index]
        nextPoolIndex[bus] = (index + 1) % nodes.count
        oneShotPool[bus] = nodes
        return player
    }

    private func loadFile(at path: String) -> AVAudioFile? {
        if let cached = fileCache[path] { return cached }
        // `path` is a relative manifest path like "music/bards-tale.m4a".
        // `Bundle.url(forResource:...)` expects the *basename* without the
        // extension, plus an optional subdirectory — passing the full
        // "music/bards-tale" silently fails to find anything.
        //
        // Xcode's resource-bundling flattens the subdirectory structure by
        // default (every file lands at the .app root), so we try multiple
        // candidate locations in order of specificity: the original Audio/
        // subdirectory layout (in case future bundle layouts preserve it),
        // then the bus-named subdir alone, then the bundle root.
        let nsPath = path as NSString
        let basename = (nsPath.lastPathComponent as NSString).deletingPathExtension
        let ext = nsPath.pathExtension
        let subdir = nsPath.deletingLastPathComponent
        let candidates: [URL?] = [
            bundle.url(forResource: basename, withExtension: ext, subdirectory: "Audio/\(subdir)"),
            bundle.url(forResource: basename, withExtension: ext, subdirectory: subdir),
            bundle.url(forResource: basename, withExtension: ext)
        ]
        guard let url = candidates.compactMap(\.self).first else { return nil }
        do {
            let file = try AVAudioFile(forReading: url)
            fileCache[path] = file
            return file
        } catch {
            return nil
        }
    }
}
