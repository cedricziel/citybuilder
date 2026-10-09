import CityCore
import Foundation
import Testing
@testable import CityUI

// Scenarios from openspec/changes/redesign-hud-map-first/specs/platform-shells/spec.md.

@MainActor
@Test("scenario: double speed runs two ticks per timer firing")
func scenarioDoubleSpeedRunsTwoTicksPerTimerFiring() {
    let session = GameSession()
    session.speed = .double
    let before = session.world.tickCount
    session.timerFired()
    #expect(session.world.tickCount == before + 2)
}

@Test("scenario: compact speed button cycles")
func scenarioCompactSpeedButtonCycles() {
    var speed = GameSpeed.normal
    var seen: [String] = []
    for _ in 0 ..< 3 {
        speed = speed.next
        seen.append(speed.label)
    }
    #expect(seen == ["2×", "3×", "1×"])
}
