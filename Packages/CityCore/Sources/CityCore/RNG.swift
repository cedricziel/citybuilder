import Foundation

/// Splitmix64-based deterministic RNG. Tiny, fast, well-mixed, and produces a
/// byte-stable sequence across platforms and Swift versions — which is the
/// load-bearing property for determinism (spec `simulation-core`).
public struct DeterministicRNG: Hashable, Codable, Sendable {
    public private(set) var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var result = state
        result = (result ^ (result &>> 30)) &* 0xBF58_476D_1CE4_E5B9
        result = (result ^ (result &>> 27)) &* 0x94D0_49BB_1331_11EB
        result = result ^ (result &>> 31)
        return result
    }
}
