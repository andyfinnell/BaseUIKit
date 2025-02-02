import SwiftUI

public struct SliderField: View {
    private let title: String
    private var value: Binding<Double>
    private let range: ClosedRange<Double>
    
    public init(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>) {
        self.title = title
        self.value = value
        self.range = range
    }
    
    public var body: some View {
        HStack {
            Slider(
                value: value,
                in: range
            )
            .controlSize(.mini)
            .frame(minWidth: 100)
            .padding()

            TextField(
                title,
                text: Binding<String>(
                    get: {
                        formatValue(value.wrappedValue)
                    },
                    set: {
                        value.wrappedValue = parseValue($0)
                    }
                )
            )
            #if os(macOS)
            .textFieldStyle(.squareBorder)
            .frame(width: 50)
            #endif
            #if os(iOS)
            .textFieldStyle(.roundedBorder)
            .keyboardType(.decimalPad)
            .frame(width: 60)
            #endif
            .autocorrectionDisabled(true)
            .multilineTextAlignment(.leading)
            .labelsHidden()
        }
    }
}

private extension SliderField {
    private static let numberFormater: NumberFormatter = {
       let formatter = NumberFormatter()
        return formatter
    }()

    func formatValue(_ value: Double) -> String {
        SliderField.numberFormater.string(for: value) ?? "0"
    }
    
    func parseValue(_ value: String) -> Double {
        let parsedNumber = SliderField.numberFormater.number(from: value) ?? NSNumber(value: 0.0)
        let number = parsedNumber.doubleValue
        return min(1, max(0, number))
    }
}
