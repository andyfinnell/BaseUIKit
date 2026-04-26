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

    public static func multiselectValue<C: RandomAccessCollection & Sendable>(
        sources: C,
        value: KeyPath<C.Element, Double> & Sendable
    ) -> Double {
        sources.reduce(Double?.none) { sum, element in
            let elementValue = element[keyPath: value]
            if sum == nil {
                return elementValue
            } else if let sum, sum == elementValue {
                return sum
            } else {
                return Double.infinity
            }
        } ?? 0.0
    }

    public static func doubleValue(_ value: Double) -> Double {
        value
    }
    
    public static func fromDoubleValue(_ number: Double, existing: Double) -> Double {
        number
    }
}

public struct OpacityField: View {
    /// Layout style for the slider. `.popover` (default) keeps the slider behind a tap-to-expand
    /// button — best when inspector space is tight. `.inline` shows the slider always-visible
    /// next to the text field — best when there's room for it (e.g. the Appearance panel's
    /// dedicated opacity row).
    public enum Style: Hashable, Sendable {
        case popover
        case inline
    }

    private let value: SmartBind<Double, ExtraEmpty>
    private let style: Style
    private let onBeginEditing: Callback<Void>
    private let onEndEditing: Callback<Void>

    public init(
        value: Double,
        onChange: @escaping (Double) -> Void,
        style: Style = .popover,
        onBeginEditing: @escaping () -> Void = {},
        onEndEditing: @escaping () -> Void = {}
    ) {
        self.value = SmartBind(value, onChange)
        self.style = style
        self.onBeginEditing = Callback(onBeginEditing)
        self.onEndEditing = Callback(onEndEditing)
    }

    public init(
        value: Binding<Double>,
        style: Style = .popover,
        onBeginEditing: @escaping () -> Void = {},
        onEndEditing: @escaping () -> Void = {}
    ) {
        self.init(value: value.wrappedValue, onChange: { value.wrappedValue = $0 }, style: style, onBeginEditing: onBeginEditing, onEndEditing: onEndEditing)
    }

    public init<C: RandomAccessCollection & Sendable>(
        sources: C,
        value: KeyPath<C.Element, Double> & Sendable,
        onChange: @escaping (Double) -> Void,
        style: Style = .popover,
        onBeginEditing: @escaping () -> Void = {},
        onEndEditing: @escaping () -> Void = {}
    ) {
        self.init(
            value: OpacityFieldParser.multiselectValue(sources: sources, value: value),
            onChange: onChange,
            style: style,
            onBeginEditing: onBeginEditing,
            onEndEditing: onEndEditing
        )
    }

    public var body: some View {
        switch style {
        case .popover:
            PopOverSliderField<OpacityFieldParser>(
                "Opacity",
                value: value,
                in: 0...1,
                onBeginEditing: onBeginEditing,
                onEndEditing: onEndEditing
            )
        case .inline:
            InlineSliderField<OpacityFieldParser>(
                "Opacity",
                value: value,
                in: 0...1,
                onBeginEditing: onBeginEditing,
                onEndEditing: onEndEditing
            )
        }
    }
}

private struct OpacityFieldPreview: View {
    @State private var opacity = 1.0
    
    var body: some View {
        OpacityField(value: opacity, onChange: { opacity = $0 })
    }
}

#Preview {
    OpacityFieldPreview()
        .frame(maxWidth: 280)
        .padding()
}
