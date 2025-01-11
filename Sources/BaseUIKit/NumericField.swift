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

public typealias NumericField = ValueField<NumericFieldParser>
