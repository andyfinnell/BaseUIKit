import SwiftUI

public struct FieldParserError: Error {
    public let message: String
    
    public init(message: String) {
        self.message = message
    }
}

public protocol FieldParser<Value> {
    associatedtype Value: Equatable
    
    static func parseValue(_ text: String) -> Result<Value, FieldParserError>
    static func formatValue(_ value: Value) -> String
    
    static func multiselectBinding<C: RandomAccessCollection & Sendable>(
        sources: C,
        value: KeyPath<C.Element, Binding<Value>> & Sendable
    ) -> Binding<Value>
}

public struct ValueField<Parser: FieldParser>: View {
    private let title: String
    private let value: Binding<Parser.Value>
    @State private var errorMessage: String?
    @State private var text: String = ""

    public init(_ title: String, value: Binding<Parser.Value>, errorMessage: String? = nil) {
        self.title = title
        self.value = value
        self.errorMessage = errorMessage
    }
    
    public init<C: RandomAccessCollection & Sendable>(
        _ title: String,
        sources: C,
        value: KeyPath<C.Element, Binding<Parser.Value>> & Sendable,
        in range: ClosedRange<Double>,
        errorMessage: String? = nil
    ) {
        self.init(
            title,
            value: Parser.multiselectBinding(sources: sources, value: value),
            errorMessage: errorMessage
        )
    }

    public var body: some View {
        VStack {
            TextField(
                text: $text,
                prompt: Text(title),
                label: {
                    Text(title)
                        .multilineTextAlignment(.trailing)
                }
            )
            #if os(macOS)
            .textFieldStyle(.squareBorder)
            #endif
            #if os(iOS)
            .textFieldStyle(.roundedBorder)
            .keyboardType(.decimalPad)
            #endif
            .autocorrectionDisabled(true)
            .multilineTextAlignment(.trailing)
            .frame(idealWidth: 120, maxWidth: 120)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.red)
            }
        }
        .onChange(of: value.wrappedValue, initial: true) { oldValue, newValue in
            text = Parser.formatValue(newValue)
        }
        .onChange(of: text) { oldValue, newValue in
            guard newValue != oldValue else {
                return
            }
            
            switch Parser.parseValue(newValue) {
            case let .success(newValue):
                value.wrappedValue = newValue
                errorMessage = nil
            case let .failure(error):
                errorMessage = error.message
            }
        }
    }
}
