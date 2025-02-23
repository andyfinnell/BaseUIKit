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
    static func hasChanged(_ old: Value, _ new: Value) -> Bool
    
    static func multiselectBinding<C: RandomAccessCollection & Sendable>(
        sources: C,
        value: KeyPath<C.Element, Binding<Value>> & Sendable
    ) -> Binding<Value>
    
    static func multiselectValue<C: RandomAccessCollection & Sendable>(
        sources: C,
        value: KeyPath<C.Element, Value> & Sendable
    ) -> Value
}

public struct ValueField<Parser: FieldParser>: View {
    private let title: String
    private let value: Parser.Value
    private let onChange: (Parser.Value) -> Void
    private let onBeginEditing: () -> Void
    private let onEndEditing: () -> Void
    @State private var errorMessage: String?
    @State private var text: String = ""
    @State private var isTextEditing = false
    @FocusState private var isFocused: Bool

    public init(
        _ title: String,
        value: Parser.Value,
        onChange: @escaping (Parser.Value) -> Void,
        errorMessage: String? = nil,
        onBeginEditing: @escaping () -> Void = {},
        onEndEditing: @escaping () -> Void = {}
    ) {
        self.title = title
        self.value = value
        self.onChange = onChange
        self.errorMessage = errorMessage
        self.onBeginEditing = onBeginEditing
        self.onEndEditing = onEndEditing
    }
    
    public init<C: RandomAccessCollection & Sendable>(
        _ title: String,
        sources: C,
        value: KeyPath<C.Element, Parser.Value> & Sendable,
        onChange: @escaping (Parser.Value) -> Void,
        errorMessage: String? = nil,
        onBeginEditing: @escaping () -> Void = {},
        onEndEditing: @escaping () -> Void = {}
    ) {
        self.init(
            title,
            value: Parser.multiselectValue(sources: sources, value: value),
            onChange: onChange,
            errorMessage: errorMessage,
            onBeginEditing: onBeginEditing,
            onEndEditing: onEndEditing
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
            .focused($isFocused)
            .onSubmit {
                endTextEditingIfNecessary()
            }
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
        .onChange(of: value, initial: true) { oldValue, newValue in
            text = Parser.formatValue(newValue)
        }
        .onChange(of: text) { oldValue, newValue in
            guard newValue != oldValue else {
                return
            }
            
            switch Parser.parseValue(newValue) {
            case let .success(newValue):
                if Parser.hasChanged(value, newValue) {
                    beginTextEditingIfNecessary()
                    onChange(newValue)
                }
                errorMessage = nil
            case let .failure(error):
                errorMessage = error.message
            }
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

private extension ValueField {
    func beginTextEditingIfNecessary() {
        guard isFocused && !isTextEditing else {
            return
        }
        isTextEditing = true
        onBeginEditing()
    }
    
    func endTextEditingIfNecessary() {
        guard isTextEditing else {
            return
        }
        isTextEditing = false
        onEndEditing()
    }
}
