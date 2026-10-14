import Testing
@testable import CityUI

// Tests for spec `platform-shells` — "Settings exposes audio sliders",
// the Apple TV stepped variant.

@Test("scenario: stepped volume clamps at the top")
func scenarioSteppedVolumeClampsAtTheTop() {
    let music = SteppedValue(value: 0.95, step: 0.1, range: 0 ... 1, format: .percent)
    let raised = music.incremented()
    #expect(raised.value == 1.0)
    #expect(raised.text == "100%")
}

@Test("Stepped value clamps at the bottom and steps by its step")
func steppedValueClampsAtTheBottom() {
    let quantity = SteppedValue(value: 10, step: 5, range: 5 ... 50, format: .integer)
    #expect(quantity.decremented().value == 5)
    #expect(quantity.decremented().decremented().value == 5)
    #expect(quantity.incremented().value == 15)
    #expect(quantity.incremented().text == "15")
}

@Test("Stepped value reports when a step can move it")
func steppedValueReportsItsBounds() {
    let top = SteppedValue(value: 1, step: 0.1, range: 0 ... 1, format: .percent)
    #expect(!top.canIncrement)
    #expect(top.canDecrement)
    #expect(top.decremented().text == "90%")
}
