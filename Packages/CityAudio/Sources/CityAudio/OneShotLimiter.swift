import Foundation

/// Whether a one-shot may start, by how recently its file started. A frame
/// can dispatch the same cue many times (#264). Spec: `audio-playback` /
/// Identical one-shots are rate-limited.
struct OneShotLimiter {
    /// The span `cap` counts starts over.
    static let window: TimeInterval = 1
    /// Starts of one file closer together than this are one sound.
    let gap: TimeInterval
    /// At most this many starts of one file within `window`.
    let cap: Int
    /// Recent start times, oldest first, by file.
    private var starts: [String: [TimeInterval]] = [:]

    /// No limit, for tests of the pool itself.
    static let unlimited = OneShotLimiter(gap: 0, cap: .max)

    init(gap: TimeInterval = 0.05, cap: Int = 6) {
        self.gap = gap
        self.cap = cap
    }

    /// Records a start of `file` at `now` and returns true, or returns false
    /// when the start would come too soon or too often.
    mutating func admits(_ file: String, at now: TimeInterval) -> Bool {
        var recent = starts.removeValue(forKey: file) ?? []
        defer { starts[file] = recent }
        recent.removeAll { now - $0 >= Self.window }
        if let last = recent.last, now - last < gap { return false }
        guard recent.count < cap else { return false }
        recent.append(now)
        return true
    }
}
