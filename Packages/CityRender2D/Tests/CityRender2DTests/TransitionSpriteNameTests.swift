import Testing
@testable import CityRender2D

// Terrain transition tiles in the naming grammar (`replace-generative-sprites-with-isokit`,
// sprite-asset-pipeline: Sprite naming grammar).
struct TransitionSpriteNameTests {
    @Test("scenario: Transition tile name accepted")
    func transitionTileNameAccepted() {
        #expect(SpriteName.validate("terrain-beach-water-t9").isSuccess)
        #expect(SpriteName.validate("terrain-grass-beach-t14").isSuccess)
        #expect(SpriteName.validate("terrain-beach-water-t1-2").isSuccess) // animated frame
        #expect(SpriteName.validate("terrain-beach-water-t9@2x").isSuccess)
    }

    @Test("scenario: Transition tile with an undeclared pair rejected")
    func undeclaredPairRejected() {
        #expect(SpriteName.validate("terrain-grass-water-t3").failure == .transitionPairUnknown)
        #expect(SpriteName.validate("terrain-beach-grass-t3").failure == .transitionPairUnknown)
    }

    @Test("scenario: Transition mask out of range rejected")
    func maskOutOfRangeRejected() {
        #expect(SpriteName.validate("terrain-grass-beach-t15").failure == .transitionMaskOutOfRange)
        #expect(SpriteName.validate("terrain-grass-beach-t0").failure == .transitionMaskOutOfRange)
    }

    @Test("plain terrain names and variants are not transitions")
    func plainTerrainUnaffected() {
        #expect(SpriteName.validate("terrain-grass-autumn-1").isSuccess)
        #expect(SpriteName.validate("terrain-mountain-v2").isSuccess)
    }
}

private extension Result where Success == Void, Failure == SpriteName.ValidationError {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var failure: SpriteName.ValidationError? {
        if case let .failure(error) = self { return error }
        return nil
    }
}
