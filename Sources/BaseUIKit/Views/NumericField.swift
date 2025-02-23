import SwiftUI

public struct NumericFieldParser: SliderFieldParser {
    private static let numberFormater: NumberFormatter = {
       let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
    
    public static func parseValue(_ text: String) -> Result<Double, FieldParserError> {
        guard let parsedNumber = numberFormater.number(from: text) else {
            return Result.failure(FieldParserError(message: "Invalid number"))
        }
        let number = parsedNumber.doubleValue
        return Result.success(number)
    }
    
    public static func formatValue(_ value: Double) -> String {
        numberFormater.string(for: value) ?? ""
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

public typealias NumericField = ValueField<NumericFieldParser>
public typealias NumericStepperField = ValueStepperField<NumericFieldParser>

struct PreviewNumericField: View {
    @State private var x: Double = 0.0
    
    var body: some View {
        NumericStepperField("X", value: x, onChange: { x = $0 }, step: 0.1)
    }
}

#Preview {
    VStack {
        HStack {
            PreviewNumericField()
                .padding()
         
            Spacer()
        }
        
        Spacer()
    }
}
