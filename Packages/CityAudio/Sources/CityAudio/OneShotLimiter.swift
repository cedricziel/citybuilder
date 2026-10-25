import Foundation

/// Whether a one-shot may start, by how recently the same cue started: the
/// same file for the same binding key. A frame can dispatch the same cue
/// many times (#264). Spec: `audio-playback` / Identical one-shots are
/// rate-limited.
struct OneShotLimiter {
    /// The span `cap` counts starts over.
    static let window: TimeInterval = 1
    /// Starts of one cue closer together than this are one sound.
    static let gap: TimeInterval = 0.05
    /// At most this many starts of one cue within `window`.
    static let cap = 6
    /// Recent start times, oldest first, by cue.
    private var starts: [String: [TimeInterval]] = [:]

    /// Records a start of the cue `key` at `now` and returns true, or returns
    /// false when the start would come too soon or too often.
    mutating func admits(_ key: String, at now: TimeInterval) -> Bool {
        var recent = starts.removeValue(forKey: key) ?? []
        defer { starts[key] = recent }
        recent.removeAll { now - $0 >= Self.window }
        if let last = recent.last, now - last < Self.gap { return false }
        guard recent.count < Self.cap else { return false }
        recent.append(now)
        return true
    }
}
