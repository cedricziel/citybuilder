# fixed-point-math Specification

## Purpose
TBD - created by archiving change add-archipelago-and-sea. Update Purpose after archive.

## Requirements
### Requirement: Fixed-point numeric type
`CityCore` SHALL provide a `Fixed` numeric type with `Int32` raw storage and an implicit scale of `4096` (i.e. 12 fractional bits, one unit = 1/4096 tile). The type MUST be `Hashable`, `Codable`, `Sendable`, and support the arithmetic operators `+`, `-`, `*`, `/`, unary `-`, and the comparison operators `<`, `<=`, `==`, `>=`, `>`.

#### Scenario: Fixed encodes and decodes to identical value
- **WHEN** a `Fixed` value `f` is encoded with `JSONEncoder` and decoded with `JSONDecoder`
- **THEN** the decoded value's `raw` field equals `f.raw`

#### Scenario: Addition is associative for in-range values
- **WHEN** three `Fixed` values `a`, `b`, `c` whose raw fields sum without overflow are added as `(a + b) + c` and as `a + (b + c)`
- **THEN** both expressions produce the same `Fixed` value

#### Scenario: Multiplication preserves scale
- **WHEN** `Fixed(1.0) * Fixed(1.0)` is evaluated (raw 4096 × raw 4096, scaled back by 4096)
- **THEN** the result equals `Fixed(1.0)` (raw 4096)

#### Scenario: Comparison matches integer comparison of raw fields
- **WHEN** any two `Fixed` values `a` and `b` are compared
- **THEN** `a < b` iff `a.raw < b.raw`

### Requirement: 2D vector type
`CityCore` SHALL provide a `Fixed2D` value type composed of two `Fixed` fields `x` and `y`. The type MUST be `Hashable`, `Codable`, `Sendable`, and support vector `+`, `-`, scalar `*` by `Fixed`, dot product, squared length, and a `distance(to:)` query returning `Fixed`.

#### Scenario: Vector round-trip preserves both components
- **WHEN** a `Fixed2D(x: a, y: b)` is encoded and decoded
- **THEN** the decoded vector's `x.raw` and `y.raw` match the original

#### Scenario: Distance is symmetric
- **WHEN** `p.distance(to: q)` and `q.distance(to: p)` are evaluated for arbitrary in-range `Fixed2D` values
- **THEN** the two results are equal

### Requirement: Trigonometric lookup tables
`CityCore` SHALL provide `Fixed.sin(_:)`, `Fixed.cos(_:)`, and `Fixed.atan2(_:_:)` implemented over a 1024-entry static lookup table indexed by `Fixed` angle. The table data MUST be deterministic `let` constants, identical across all build targets and platforms.

#### Scenario: sin at zero
- **WHEN** `Fixed.sin(Fixed(0))` is evaluated
- **THEN** the result is `Fixed(0)`

#### Scenario: cos at zero
- **WHEN** `Fixed.cos(Fixed(0))` is evaluated
- **THEN** the result is `Fixed(1.0)` (raw 4096)

#### Scenario: atan2 of canonical axis directions
- **WHEN** `Fixed.atan2(Fixed(0), Fixed(1.0))` is evaluated
- **THEN** the result is `Fixed(0)`

#### Scenario: Lookup tables are byte-identical across platforms
- **WHEN** the trig table backing storage is hashed on macOS and on Linux build runners
- **THEN** the two hashes are identical

### Requirement: Float ban in tick-time code
No function reachable from `World.tick(_:)` SHALL reference `Float`, `Double`, `CGFloat`, or any standard-library function whose result depends on IEEE-754 rounding modes. The ban MUST be enforced by a custom SwiftLint rule and by a code-review checklist.

#### Scenario: SwiftLint rule flags Double in tick path
- **WHEN** a file under `Sources/CityCore/Systems/` introduces a `Double` literal or variable inside a function transitively called by `World.tick(_:)`
- **THEN** SwiftLint emits a violation with rule identifier `tick_float_ban`

#### Scenario: Renderer is exempt from the ban
- **WHEN** a file under `Sources/CityRender2D/` uses `CGFloat`
- **THEN** the SwiftLint `tick_float_ban` rule does NOT fire

### Requirement: Cross-platform determinism gate
CI SHALL include a determinism job that builds `CityCore` on both macOS and a Linux Swift toolchain, runs a fixed archipelago scenario for 6000 simulation ticks on each, and asserts the post-run `World` Codable JSON is byte-identical between the two runs.

#### Scenario: Determinism gate blocks PRs on divergence
- **WHEN** a PR changes a function reachable from `World.tick(_:)` in a way that produces different post-tick state on macOS vs Linux for the determinism-scenario fixture
- **THEN** the determinism CI job fails and blocks merge

#### Scenario: Determinism gate passes when math is platform-agnostic
- **WHEN** a PR changes only `Fixed` arithmetic or ship integration code in ways that compute identically on both platforms
- **THEN** the determinism CI job passes
