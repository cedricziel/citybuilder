import CityCore
import Testing
@testable import CityUI

// Haptic feedback for placement, refusal and event warnings. What the
// device feels cannot be checked here, only which feedback is asked for.

@MainActor
private final class RecordingHaptics: HapticPlaying {
    var played: [HapticFeedback] = []

    func play(_ feedback: HapticFeedback) {
        played.append(feedback)
    }
}

@MainActor
private func hapticSession() -> (GameSession, RecordingHaptics) {
    let session = GameSession(world: World.fixtureWithTerrain(width: 6, height: 6, fill: .grass, seed: 1))
    let haptics = RecordingHaptics()
    session.haptics = haptics
    session.confirmsBuildingPlacement = false
    return (session, haptics)
}

@MainActor
@Suite("Haptics")
struct HapticsTests {
    @Test("placing a road gives one light placement tap")
    func placing() {
        let (session, haptics) = hapticSession()
        session.selectTool(.place(.road))
        session.handleTap(at: TileCoordinate(x: 2, y: 2))
        #expect(haptics.played == [.placed])
    }

    @Test("a refused placement gives one refusal and no placement tap")
    func refusing() {
        let (session, haptics) = hapticSession()
        session.selectTool(.place(.road))
        session.handleTap(at: TileCoordinate(x: 99, y: 99))
        #expect(haptics.played == [.refused])
    }

    @Test("painting a road by dragging gives no haptic")
    func dragging() {
        let (session, haptics) = hapticSession()
        session.selectTool(.place(.road))
        session.handleDrag(at: TileCoordinate(x: 1, y: 1))
        session.handleDrag(at: TileCoordinate(x: 2, y: 1))
        #expect(haptics.played.isEmpty)
    }

    @Test("a seasonal event warning gives one warning")
    func eventWarning() {
        let (session, haptics) = hapticSession()
        session.noteBannerEvents(in: [.seasonalEventWarned(event: .fire, onset: .summer)])
        #expect(haptics.played == [.warning])
    }

    @Test("a completed monument gives a success")
    func monument() {
        let (session, haptics) = hapticSession()
        session.noteBannerEvents(in: [.monumentCompleted(building: EntityID(raw: 2))])
        #expect(haptics.played == [.success])
    }

    @Test("other events stay silent")
    func quiet() {
        let (session, haptics) = hapticSession()
        session.noteBannerEvents(in: [.commissionEnded(building: EntityID(raw: 4))])
        #expect(haptics.played.isEmpty)
    }
}
