import Testing
@testable import CityAudio

// Spec `audio-playback`: "Identical one-shots are rate-limited".

/// How many of the starts of `file` at `times` the limiter admits.
private func admitted(_ times: [Double], key: String = "carrierArrived sfx/clink.caf", limiter: inout OneShotLimiter) -> Int {
    times.count(where: { limiter.admits(key, at: $0) })
}

@Test("scenario: a burst in one frame plays once (limiter)")
func limiterAdmitsOneOfABurst() {
    var limiter = OneShotLimiter()
    #expect(admitted(Array(repeating: 10, count: 100), limiter: &limiter) == 1)
}

@Test("scenario: spaced cues all play")
func limiterAdmitsSpacedCues() {
    var limiter = OneShotLimiter()
    #expect(admitted([10, 10.2, 10.4, 10.6, 10.8], limiter: &limiter) == 5)
}

@Test("scenario: at most six a second")
func limiterCapsCuesPerSecond() {
    var limiter = OneShotLimiter()
    let times = (0 ..< 17).map { 10 + Double($0) * 0.06 }
    #expect(admitted(times, limiter: &limiter) == 6)
    // A second later the window has moved on.
    #expect(admitted([12], limiter: &limiter) == 1)
}

@Test("scenario: different cues don't hold each other back")
func limiterKeepsCuesApart() {
    var limiter = OneShotLimiter()
    #expect(admitted([10], key: "carrierArrived sfx/clink.caf", limiter: &limiter) == 1)
    #expect(admitted([10], key: "taxesCollected sfx/coin.caf", limiter: &limiter) == 1)
    #expect(admitted([10], key: "rivalAgeAdvanced sfx/age-peal.caf", limiter: &limiter) == 1)
    #expect(admitted([10], key: "ageAdvanced sfx/age-peal.caf", limiter: &limiter) == 1)
}
