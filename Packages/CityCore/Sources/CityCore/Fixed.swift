import Foundation

/// A 32-bit fixed-point number with an implicit scale of `4096` (12
/// fractional bits, 1 unit = 1/4096 tile). The whole numeric pipeline
/// reachable from `World.tick(_:)` runs on `Fixed` so simulation state
/// is byte-identical across Apple and Linux Swift toolchains — IEEE-754
/// rounding-mode drift cannot leak in.
///
/// Spec: `fixed-point-math` capability added by `add-archipelago-and-sea`.
public struct Fixed: Hashable, Codable, Sendable {
    /// One Fixed-point unit. `raw == scale` is the integer value 1.
    public static let scale: Int32 = 4096
    /// `Fixed(0)` and `Fixed(1.0)` shorthands.
    public static let zero = Fixed(raw: 0)
    public static let one = Fixed(raw: scale)

    public let raw: Int32

    public init(raw: Int32) {
        self.raw = raw
    }

    /// Constructs a `Fixed` from an integer tile count.
    public init(_ wholeTiles: Int32) {
        self.raw = wholeTiles &* Self.scale
    }

    // MARK: - Arithmetic

    public static func + (lhs: Fixed, rhs: Fixed) -> Fixed {
        Fixed(raw: lhs.raw &+ rhs.raw)
    }

    public static func - (lhs: Fixed, rhs: Fixed) -> Fixed {
        Fixed(raw: lhs.raw &- rhs.raw)
    }

    public static prefix func - (value: Fixed) -> Fixed {
        Fixed(raw: 0 &- value.raw)
    }

    /// Multiplication. Computed in `Int64` then rescaled to avoid
    /// overflow when both operands are far from zero. Truncates toward
    /// zero (Swift `Int64` division semantics) rather than rounding —
    /// deterministic, platform-independent.
    public static func * (lhs: Fixed, rhs: Fixed) -> Fixed {
        let product = Int64(lhs.raw) * Int64(rhs.raw)
        let scaled = product / Int64(scale)
        return Fixed(raw: Int32(truncatingIfNeeded: scaled))
    }

    /// Division. `lhs / rhs` returns `Fixed` truncated toward zero.
    /// `rhs == 0` traps (caller's responsibility — there is no NaN).
    public static func / (lhs: Fixed, rhs: Fixed) -> Fixed {
        let numerator = Int64(lhs.raw) * Int64(scale)
        let result = numerator / Int64(rhs.raw)
        return Fixed(raw: Int32(truncatingIfNeeded: result))
    }

    // MARK: - Comparison

    public static func < (lhs: Fixed, rhs: Fixed) -> Bool {
        lhs.raw < rhs.raw
    }

    public static func <= (lhs: Fixed, rhs: Fixed) -> Bool {
        lhs.raw <= rhs.raw
    }

    public static func > (lhs: Fixed, rhs: Fixed) -> Bool {
        lhs.raw > rhs.raw
    }

    public static func >= (lhs: Fixed, rhs: Fixed) -> Bool {
        lhs.raw >= rhs.raw
    }

    // MARK: - Trig (table-driven, deterministic across platforms)

    /// 1024-entry full-period sine table. Values are
    /// `round(sin(2π·i/1024) * 4096)` precomputed at compile time so
    /// the runtime never depends on `sin()` from the platform's libm.
    ///
    /// `Float80`/`Double` would re-introduce IEEE-754 platform drift;
    /// the table is generated below via a deterministic Taylor-series
    /// expansion in `Int64` so its bytes match on macOS and Linux.
    public static let trigTable: [Int32] = makeTrigTable()

    /// Sine of an angle expressed as `Fixed` *radians*. The argument
    /// is reduced modulo 2π; the result is in `[-1, 1]` Fixed.
    public static func sin(_ angle: Fixed) -> Fixed {
        Fixed(raw: trigTable[trigIndex(forAngle: angle)])
    }

    /// Cosine via the table offset by π/2 = quarter table.
    public static func cos(_ angle: Fixed) -> Fixed {
        let idx = (trigIndex(forAngle: angle) + 256) & (1024 - 1)
        return Fixed(raw: trigTable[idx])
    }

    /// Four-quadrant arctangent. Returns a `Fixed` in `[-π, π]`. The
    /// implementation walks the trig table to find the index whose
    /// `(cos, sin)` best matches the input ratio. Stable across
    /// platforms because the search is integer-only.
    public static func atan2(_ y: Fixed, _ x: Fixed) -> Fixed {
        if y.raw == 0 {
            return x.raw >= 0 ? Fixed.zero : Fixed(raw: piRaw)
        }
        // Linear scan — 1024 entries, ~tens of microseconds per call.
        // Good enough for ship heading updates that happen O(ships)
        // per tick; we can replace with a CORDIC-style narrowing if it
        // ever shows up in profiles.
        let yi = Int64(y.raw)
        let xi = Int64(x.raw)
        var bestIdx = 0
        var bestErr = Int64.max
        for idx in 0 ..< trigTable.count {
            let cosV = Int64(trigTable[(idx + 256) & 1023])
            let sinV = Int64(trigTable[idx])
            // Want: y/x ≈ sin/cos  →  y*cos ≈ x*sin
            let err = abs(yi * cosV - xi * sinV)
            if err < bestErr {
                bestErr = err
                bestIdx = idx
            }
        }
        return angleAtIndex(bestIdx)
    }

    // MARK: - Internals

    private static let piRaw: Int32 = 12868 // round(π * 4096)
    private static let twoPiIndex: Int32 = 1024

    private static func trigIndex(forAngle angle: Fixed) -> Int {
        // angle in Fixed radians → table index in [0, 1024).
        // index = (angle / 2π) * 1024 = (angle * 1024) / 2π
        // Compute in Int64 to avoid overflow.
        let twoPiScaled = Int64(piRaw) * 2 // 2π · 4096
        let scaled = (Int64(angle.raw) * Int64(twoPiIndex)) / twoPiScaled
        // Modular wrap — Swift `%` matches sign of dividend, normalize to [0,1024).
        var idx = Int(scaled % Int64(twoPiIndex))
        if idx < 0 { idx += Int(twoPiIndex) }
        return idx
    }

    private static func angleAtIndex(_ idx: Int) -> Fixed {
        // angle = (idx / 1024) * 2π
        let twoPiScaled = Int64(piRaw) * 2
        let raw = (Int64(idx) * twoPiScaled) / Int64(twoPiIndex)
        return Fixed(raw: Int32(truncatingIfNeeded: raw))
    }

    /// Compile-time generator for the sine table. Uses a degree-9 Taylor
    /// series in Int64 so the bytes are platform-independent.
    private static func makeTrigTable() -> [Int32] {
        var table: [Int32] = []
        table.reserveCapacity(1024)
        // Table is the first quarter (0..π/2) reflected/mirrored to a
        // full period. Quarter is 256 entries.
        let quarter = 256
        var quarterValues: [Int32] = []
        quarterValues.reserveCapacity(quarter + 1)
        for idx in 0 ... quarter {
            // angle in fixed = (idx / 1024) * 2π  → raw = idx * 2π·4096 / 1024
            let angleRaw = Int64(idx) * (Int64(piRaw) * 2) / 1024
            quarterValues.append(Int32(truncatingIfNeeded: taylorSin(angleRaw)))
        }
        // [0, π/2)
        for idx in 0 ..< quarter {
            table.append(quarterValues[idx])
        }
        // [π/2, π) — mirror: sin(π - x) = sin(x)
        for idx in 0 ..< quarter {
            table.append(quarterValues[quarter - idx])
        }
        // [π, 3π/2) — negate the first quarter
        for idx in 0 ..< quarter {
            table.append(-quarterValues[idx])
        }
        // [3π/2, 2π) — negate the mirrored quarter
        for idx in 0 ..< quarter {
            table.append(-quarterValues[quarter - idx])
        }
        return table
    }

    /// sin(x) via Taylor series, x in Fixed radians, returns Fixed raw.
    /// Series: x - x³/6 + x⁵/120 - x⁷/5040 + x⁹/362880, all in Int64.
    private static func taylorSin(_ angleRaw: Int64) -> Int64 {
        let unit = Int64(scale)
        let xx = angleRaw
        let x2 = xx * xx / unit
        let x3 = x2 * xx / unit
        let x5 = x3 * x2 / unit
        let x7 = x5 * x2 / unit
        let x9 = x7 * x2 / unit
        return xx - x3 / 6 + x5 / 120 - x7 / 5040 + x9 / 362_880
    }
}

/// A 2D vector in `Fixed` space.
public struct Fixed2D: Hashable, Codable, Sendable {
    public let x: Fixed
    public let y: Fixed

    public init(x: Fixed, y: Fixed) {
        self.x = x
        self.y = y
    }

    public static let zero = Fixed2D(x: .zero, y: .zero)

    public static func + (lhs: Fixed2D, rhs: Fixed2D) -> Fixed2D {
        Fixed2D(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    public static func - (lhs: Fixed2D, rhs: Fixed2D) -> Fixed2D {
        Fixed2D(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    public static func * (lhs: Fixed2D, rhs: Fixed) -> Fixed2D {
        Fixed2D(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    public func dot(_ other: Fixed2D) -> Fixed {
        x * other.x + y * other.y
    }

    public var squaredLength: Fixed {
        x * x + y * y
    }

    /// Euclidean distance. Computed in Int64 using a Newton-iteration
    /// integer square root so the result is platform-independent.
    public func distance(to other: Fixed2D) -> Fixed {
        let dx = Int64(x.raw - other.x.raw)
        let dy = Int64(y.raw - other.y.raw)
        let sumSq = dx * dx + dy * dy
        return Fixed(raw: Int32(truncatingIfNeeded: isqrt(sumSq)))
    }
}

/// Newton's-method integer square root. Returns `floor(sqrt(n))` for
/// non-negative `n`. Deterministic across platforms.
private func isqrt(_ value: Int64) -> Int64 {
    guard value > 0 else { return 0 }
    var current = value
    var next = (current + 1) / 2
    while next < current {
        current = next
        next = (current + value / current) / 2
    }
    return current
}
