import Foundation

/// A value snapped to a grid of fixed steps and clamped to its range: the
/// model behind the −/+ control that replaces `Slider` and `Stepper` on
/// Apple TV. Spec: `platform-shells` / Settings exposes audio sliders.
public struct SteppedValue: Equatable, Sendable {
    public enum Format: Equatable, Sendable {
        case percent
        case integer
    }

    public let value: Double
    public let step: Double
    public let range: ClosedRange<Double>
    public let format: Format

    public init(value: Double, step: Double, range: ClosedRange<Double>, format: Format) {
        let snapped = range.lowerBound + ((value - range.lowerBound) / step).rounded() * step
        self.value = min(max(snapped, range.lowerBound), range.upperBound)
        self.step = step
        self.range = range
        self.format = format
    }

    public var canIncrement: Bool {
        value < range.upperBound
    }

    public var canDecrement: Bool {
        value > range.lowerBound
    }

    public func incremented() -> SteppedValue {
        with(value: value + step)
    }

    public func decremented() -> SteppedValue {
        with(value: value - step)
    }

    public var text: String {
        switch format {
        case .percent: "\(Int((value * 100).rounded()))%"
        case .integer: "\(Int(value.rounded()))"
        }
    }

    private func with(value: Double) -> SteppedValue {
        SteppedValue(value: value, step: step, range: range, format: format)
    }
}
