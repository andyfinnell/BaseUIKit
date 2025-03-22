import SwiftUI

public struct ZoomFieldParser {
    public typealias Value = Double
    
    private static let percentFormater: NumberFormatter = {
       let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.multiplier = 100
        return formatter
    }()

    public static func parseValue(_ text: String) -> Result<Double, FieldParserError> {
        var fixedUpText = text
        fixedUpText.removeAll(where: { $0 == "%" })
        fixedUpText += "%"
        let parsedNumber = percentFormater.number(from: fixedUpText)
        guard let parsedNumber else {
            return Result.failure(FieldParserError(message: "Invalid zoom"))
        }
        let number = parsedNumber.doubleValue
        return Result.success(min(100, max(0.01, number)))
    }
    
    public static func formatValue(_ value: Double) -> String {
        percentFormater.string(for: value) ?? "0%"
    }
    
    public static func hasChanged(_ old: Double, _ new: Double) -> Bool {
        !old.isClose(to: new, threshold: 1e-6)
    }

    public static func sliderValue(
        _ zoomValue: Double,
        fromRange zoomRange: ClosedRange<Double>,
        toRange displayRange: ClosedRange<Double>
    ) -> Double {
        // We want zoomValue = 1.0 to be in the middle of displayRange, then scale everything around that
        let displayMidpoint = (displayRange.upperBound - displayRange.lowerBound) / 2.0 + displayRange.lowerBound
        return mapValue(
            zoomValue,
            fromRange: zoomRange,
            fromMidpoint: 1.0,
            toRange: displayRange,
            toMidpoint: displayMidpoint
        )
    }
    
    public static func fromSliderValue(
        _ displayValue: Double,
        fromRange displayRange: ClosedRange<Double>,
        toRange zoomRange: ClosedRange<Double>
    ) -> Double {
        // We want zoomValue = 1.0 to be in the middle of displayRange, then scale everything around that
        let displayMidpoint = (displayRange.upperBound - displayRange.lowerBound) / 2.0 + displayRange.lowerBound
        return mapValue(
            displayValue,
            fromRange: displayRange,
            fromMidpoint: displayMidpoint,
            toRange: zoomRange,
            toMidpoint: 1.0
        )
    }
}

public struct ZoomSlider: View {
    private let value: SmartBind<ZoomFieldParser.Value, ExtraEmpty>
    private let range: ClosedRange<Double>
    private let displayRange: ClosedRange<Double>
    @State private var text: String = ""
    @State private var number: Double = 0.0
    @State private var isTextEditing = false
    @FocusState private var isFocused: Bool

    public init(
        value: ZoomFieldParser.Value,
        onChange: @escaping (ZoomFieldParser.Value) -> Void
    ) {
        self.value = SmartBind(value, onChange)
        self.range = 0.01...64.0
        self.displayRange = -1000.0...1000.0
    }

    public var body: some View {
        VStack {
            HStack {
                Slider(
                    value: $number,
                    in: displayRange,
                    step: 1
                )
                .frame(minWidth: 80, maxWidth: 120)
                
                TextField(
                    text: $text,
                    prompt: Text("Zoom"),
                    label: {
                        Text("Zoom")
                            .multilineTextAlignment(.trailing)
                    }
                )
                .focused($isFocused)
                .onSubmit {
                    endTextEditingIfNecessary()
                }
#if os(macOS)
                .frame(width: 50)
#endif
#if os(iOS)
                .keyboardType(.decimalPad)
                .frame(minWidth: 60, maxWidth: 80)
#endif
                .autocorrectionDisabled(true)
                .multilineTextAlignment(.leading)
                .labelsHidden()
            }
            .controlSize(.mini)
        }
        .onChange(of: value.value, initial: true) { oldValue, newValue in
            text = ZoomFieldParser.formatValue(newValue)
            number = ZoomFieldParser.sliderValue(newValue, fromRange: range, toRange: displayRange)
        }
        .onChange(of: number) { oldValue, newValue in
            guard !newValue.isClose(to: oldValue, threshold: 1e-6) else {
                return
            }
            
            let parsedValue = ZoomFieldParser.fromSliderValue(newValue, fromRange:displayRange, toRange: range)
            if ZoomFieldParser.hasChanged(value.value, parsedValue) {
                value.onChange(parsedValue)
            }
            text = ZoomFieldParser.formatValue(parsedValue)
        }
        .onChange(of: isFocused) { oldValue, newValue in
            guard newValue != oldValue else {
                return
            }
            if !newValue {
                endTextEditingIfNecessary()
            }
        }
    }
}

private extension ZoomSlider {
    func endTextEditingIfNecessary() {
        // Since they're done, actually update the value
        switch ZoomFieldParser.parseValue(text) {
        case let .success(newValue):
            if ZoomFieldParser.hasChanged(value.value, newValue) {
                value.onChange(newValue)
            }
        case .failure:
            // Reset field
            text = ZoomFieldParser.formatValue(value.value)
        }
    }
}

private func mapValue(
    _ fromValue: Double,
    fromRange: ClosedRange<Double>,
    fromMidpoint: Double,
    toRange: ClosedRange<Double>,
    toMidpoint: Double
) -> Double {
    if fromValue == fromMidpoint {
        return toMidpoint
    } else if fromValue < fromMidpoint {
        let unitValue = (fromValue - fromRange.lowerBound) / (fromMidpoint - fromRange.lowerBound)
        let toValue = unitValue * (toMidpoint - toRange.lowerBound) + toRange.lowerBound
        return toValue
    } else {
        let unitValue = (fromValue - fromMidpoint) / (fromRange.upperBound - fromMidpoint)
        let toValue = unitValue * (toRange.upperBound - toMidpoint) + toMidpoint
        return toValue
    }
}

private struct ZoomSliderPreview: View {
    @State private var zoom = 1.0
    
    var body: some View {
        ZoomSlider(value: zoom, onChange: { zoom = $0 })
    }
}

#Preview {
    VStack {
        HStack {
            ZoomSliderPreview()
                .padding()
         
            Spacer()
        }
        Spacer()
    }
}
