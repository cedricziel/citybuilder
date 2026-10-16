import Foundation

/// Which pooled node a one-shot plays on. Spec: `audio-playback` /
/// One-shots don't cut off long sounds.
enum OneShotPool {
    /// Cues longer than this are long: a peal or a great bell.
    static let longSeconds: TimeInterval = 1.5

    struct Slot: Equatable {
        /// When the node's current cue finishes, on the uptime clock.
        var endsAt: TimeInterval
        var isLong: Bool
    }

    /// The first free node from `start` in rotation; failing that, the
    /// short cue that ends soonest; failing that, whatever ends soonest.
    static func pick(_ slots: [Slot], now: TimeInterval, from start: Int) -> Int {
        let order = slots.indices.map { (start + $0) % slots.count }
        if let free = order.first(where: { slots[$0].endsAt <= now }) {
            return free
        }
        let short = order.filter { !slots[$0].isLong }
        let candidates = short.isEmpty ? order : short
        return candidates.min { slots[$0].endsAt < slots[$1].endsAt } ?? start
    }
}
