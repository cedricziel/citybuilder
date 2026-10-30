import Foundation

/// The seeds a balance sweep runs. SWEEP_SEEDS=N keeps the first N, so a
/// sweep can be smoke-tested in minutes (`scripts/sweeps/README.md`).
func sweepSeeds(_ seeds: [UInt64]) -> [UInt64] {
    guard let limit = ProcessInfo.processInfo.environment["SWEEP_SEEDS"].flatMap(Int.init) else { return seeds }
    return Array(seeds.prefix(max(limit, 1)))
}

func sweepSeeds(_ seeds: Range<UInt64>) -> [UInt64] {
    sweepSeeds(Array(seeds))
}

/// "0-29" for seeds 0 to 29, as the sweep lines print them.
func seedSpan(_ seeds: [UInt64]) -> String {
    "\(seeds.first ?? 0)-\(seeds.last ?? 0)"
}
