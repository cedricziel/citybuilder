import SwiftUI

/// A −/+ button pair around a `SteppedValue`. Apple TV has no `Slider` or
/// `Stepper`, so it uses this control for every value in Settings and the
/// manifest editor. Holding a button repeats its step.
public struct SteppedValueControl: View {
    private let title: String
    private let stepped: SteppedValue
    private let onChange: (Double) -> Void

    public init<Value: BinaryFloatingPoint>(
        _ title: String,
        value: Binding<Value>,
        step: Double,
        range: ClosedRange<Double>,
        format: SteppedValue.Format
    ) {
        self.title = title
        stepped = SteppedValue(value: Double(value.wrappedValue), step: step, range: range, format: format)
        onChange = { value.wrappedValue = Value($0) }
    }

    public init(_ title: String, value: Binding<Int>, step: Int, range: ClosedRange<Int>) {
        self.title = title
        stepped = SteppedValue(
            value: Double(value.wrappedValue),
            step: Double(step),
            range: Double(range.lowerBound) ... Double(range.upperBound),
            format: .integer
        )
        onChange = { value.wrappedValue = Int($0.rounded()) }
    }

    public var body: some View {
        HStack {
            Text(title)
            Spacer()
            Button {
                onChange(stepped.decremented().value)
            } label: {
                Image(systemName: "minus")
            }
            .disabled(!stepped.canDecrement)
            .accessibilityLabel("Decrease \(title)")
            Text(stepped.text)
                .monospacedDigit()
                .frame(minWidth: 80)
            Button {
                onChange(stepped.incremented().value)
            } label: {
                Image(systemName: "plus")
            }
            .disabled(!stepped.canIncrement)
            .accessibilityLabel("Increase \(title)")
        }
        .buttonRepeatBehavior(.enabled)
    }
}
