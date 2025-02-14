import SwiftUI

public struct OpacityFieldParser: SliderFieldParser {
    private static let numberFormater: NumberFormatter = {
       let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.multiplier = 100
        return formatter
    }()
    
    public static func parseValue(_ text: String) -> Result<Double, FieldParserError> {
        guard let parsedNumber = numberFormater.number(from: text) else {
            return Result.failure(FieldParserError(message: "Invalid opacity"))
        }
        let number = parsedNumber.doubleValue
        return Result.success(min(1, max(0, number)))
    }
    
    public static func formatValue(_ value: Double) -> String {
        numberFormater.string(for: value) ?? "0"
    }
    
    public static func hasChanged(_ old: Double, _ new: Double) -> Bool {
        !old.isClose(to: new, threshold: 1e-6)
    }

    public static func multiselectBinding<C: RandomAccessCollection & Sendable>(
        sources: C,
        value: KeyPath<C.Element, Binding<Double>> & Sendable
    ) -> Binding<Double> {
        Binding<Double>(sources: sources, value: value)
    }

    public static func doubleValue(_ value: Double) -> Double {
        value
    }
    
    public static func fromDoubleValue(_ number: Double, existing: Double) -> Double {
        number
    }
}

public struct OpacityField: View {
    private let value: Binding<Double>
    private let onBeginEditing: () -> Void
    private let onEndEditing: () -> Void

    public init(
        value: Binding<Double>,
        onBeginEditing: @escaping () -> Void = {},
        onEndEditing: @escaping () -> Void = {}
    ) {
        self.value = value
        self.onBeginEditing = onBeginEditing
        self.onEndEditing = onEndEditing
    }

    public init<C: RandomAccessCollection & Sendable>(
        sources: C,
        value: KeyPath<C.Element, Binding<Double>> & Sendable,
        onBeginEditing: @escaping () -> Void = {},
        onEndEditing: @escaping () -> Void = {}
    ) {
        self.init(
            value: OpacityFieldParser.multiselectBinding(sources: sources, value: value),
            onBeginEditing: onBeginEditing,
            onEndEditing: onEndEditing
        )
    }

    public var body: some View {
        PopOverSliderField<OpacityFieldParser>(
            "Opacity",
            value: value,
            in: 0...1,
            onBeginEditing: onBeginEditing,
            onEndEditing: onEndEditing
        )
    }
}

private struct OpacityFieldPreview: View {
    @State private var opacity = 1.0
    
    var body: some View {
        OpacityField(value: $opacity)
    }
}

#Preview {
    OpacityFieldPreview()
        .frame(maxWidth: 280)
        .padding()
}
