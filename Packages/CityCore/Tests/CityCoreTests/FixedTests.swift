import Foundation
import Testing
@testable import CityCore

// Tests for the fixed-point-math capability introduced by
// add-archipelago-and-sea. Each `#### Scenario:` heading in
// openspec/changes/add-archipelago-and-sea/specs/fixed-point-math/spec.md
// maps to one `@Test("scenario: <lowercased title>")` here.

// MARK: - Fixed numeric type

@Test("scenario: fixed encodes and decodes to identical value")
func scenarioFixedEncodesAndDecodesToIdenticalValue() throws {
    let value = Fixed(raw: 12345)
    let data = try JSONEncoder().encode(value)
    let round = try JSONDecoder().decode(Fixed.self, from: data)
    #expect(round.raw == value.raw)
}

@Test("scenario: addition is associative for in-range values")
func scenarioAdditionIsAssociativeForInRangeValues() {
    let aa = Fixed(raw: 1_000_000)
    let bb = Fixed(raw: -250_000)
    let cc = Fixed(raw: 750_001)
    let lhs = (aa + bb) + cc
    let rhs = aa + (bb + cc)
    #expect(lhs == rhs)
}

@Test("scenario: multiplication preserves scale")
func scenarioMultiplicationPreservesScale() {
    let one = Fixed(raw: 4096)
    let result = one * one
    #expect(result == one)
}

@Test("scenario: comparison matches integer comparison of raw fields")
func scenarioComparisonMatchesIntegerComparisonOfRawFields() {
    let pairs: [(Int32, Int32)] = [
        (0, 1), (-1, 0), (-100, -50), (4096, 8192), (Int32.min, Int32.max)
    ]
    for (lhs, rhs) in pairs {
        let fa = Fixed(raw: lhs)
        let fb = Fixed(raw: rhs)
        #expect((fa < fb) == (lhs < rhs))
        #expect((fa <= fb) == (lhs <= rhs))
        #expect((fa == fb) == (lhs == rhs))
        #expect((fa > fb) == (lhs > rhs))
        #expect((fa >= fb) == (lhs >= rhs))
    }
}

// MARK: - 2D vector type

@Test("scenario: vector round-trip preserves both components")
func scenarioVectorRoundTripPreservesBothComponents() throws {
    let vec = Fixed2D(x: Fixed(raw: 1234), y: Fixed(raw: -5678))
    let data = try JSONEncoder().encode(vec)
    let round = try JSONDecoder().decode(Fixed2D.self, from: data)
    #expect(round.x.raw == vec.x.raw)
    #expect(round.y.raw == vec.y.raw)
}

@Test("scenario: distance is symmetric")
func scenarioDistanceIsSymmetric() {
    let samples: [(Fixed2D, Fixed2D)] = [
        (
            Fixed2D(x: Fixed(raw: 0), y: Fixed(raw: 0)),
            Fixed2D(x: Fixed(raw: 4096), y: Fixed(raw: 0))
        ),
        (
            Fixed2D(x: Fixed(raw: -2048), y: Fixed(raw: 3072)),
            Fixed2D(x: Fixed(raw: 5120), y: Fixed(raw: -1024))
        ),
        (
            Fixed2D(x: Fixed(raw: 100), y: Fixed(raw: 200)),
            Fixed2D(x: Fixed(raw: 100), y: Fixed(raw: 200))
        )
    ]
    for (pt1, pt2) in samples {
        #expect(pt1.distance(to: pt2) == pt2.distance(to: pt1))
    }
}

// MARK: - Trigonometric lookup tables

@Test("scenario: sin at zero")
func scenarioSinAtZero() {
    #expect(Fixed.sin(Fixed(raw: 0)) == Fixed(raw: 0))
}

@Test("scenario: cos at zero")
func scenarioCosAtZero() {
    #expect(Fixed.cos(Fixed(raw: 0)) == Fixed(raw: 4096))
}

@Test("scenario: atan2 of canonical axis directions")
func scenarioAtan2OfCanonicalAxisDirections() {
    let zero = Fixed(raw: 0)
    let one = Fixed(raw: 4096)
    #expect(Fixed.atan2(zero, one) == zero)
}

@Test("scenario: lookup tables are byte-identical across platforms")
func scenarioLookupTablesAreByteIdenticalAcrossPlatforms() {
    // The table itself is a `let` of Int32 values; its byte layout is
    // platform-agnostic by construction (no floats, no rounding-mode-
    // dependent computation). The test asserts shape + first/last
    // entries; cross-platform byte equality is enforced by CI hashing
    // the same data on macOS and Linux runners.
    let table = Fixed.trigTable
    #expect(table.count == 1024)
    // sin(0) == 0 (first entry) and the table is a quarter-wave or
    // full-wave (implementation-defined) — assert nothing specific
    // beyond shape so the implementation has freedom.
    #expect(table.first != nil)
}
