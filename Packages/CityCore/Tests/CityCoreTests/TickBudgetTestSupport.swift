#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
@testable import CityCore

/// CPU time the calling thread has used. Unlike wall-clock time it
/// doesn't grow while the thread waits for a core, so a tick budget
/// measured with it holds when the suite runs on a loaded machine.
/// `World.tick()` runs on the calling thread.
func threadCPUNanoseconds() -> UInt64 {
    var now = timespec()
    clock_gettime(CLOCK_THREAD_CPUTIME_ID, &now)
    return UInt64(now.tv_sec) * 1_000_000_000 + UInt64(now.tv_nsec)
}

/// Runs `ticks` ticks and returns the mean CPU time per tick.
func meanTickCPUNanoseconds(_ world: inout World, ticks: Int) -> UInt64 {
    let start = threadCPUNanoseconds()
    for _ in 0 ..< ticks {
        world.tick()
    }
    return (threadCPUNanoseconds() - start) / UInt64(ticks)
}
