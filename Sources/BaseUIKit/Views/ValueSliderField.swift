import SwiftUI

public protocol SliderFieldParser<Value>: FieldParser {
    static func doubleValue(_ value: Value) -> Double
    static func fromDoubleValue(_ number: Double, existing: Value) -> Value
}

public struct ValueSliderField<Parser: SliderFieldParser>: View {
    private let title: String
    private let value: SmartBind<Parser.Value, ExtraEmpty>
    private let range: ClosedRange<Double>
    private let onBeginEditing: Callback<Void>
    private let onEndEditing: Callback<Void>
    @State private var errorMessage: String?
    @State private var text: String = ""
    @State private var number: Double = 0.0
    @State private var isTextEditing = false
    @FocusState private var isFocused: Bool

    public init(
        _ title: String,
        value: Parser.Value,
        onChange: @escaping (Parser.Value) -> Void,
        in range: ClosedRange<Double>,
        errorMessage: String? = nil,
        onBeginEditing: @escaping () -> Void = {},
        onEndEditing: @escaping () -> Void = {}
    ) {
        self.title = title
        self.value = SmartBind(value, onChange)
        self.range = range
        self.onBeginEditing = Callback(onBeginEditing)
        self.onEndEditing = Callback(onEndEditing)
        self.errorMessage = errorMessage
    }
    
    public init<C: RandomAccessCollection & Sendable>(
        _ title: String,
        sources: C,
        value: KeyPath<C.Element, Parser.Value> & Sendable,
        onChange: @escaping (Parser.Value) -> Void,
        in range: ClosedRange<Double>,
        errorMessage: String? = nil,
        onBeginEditing: @escaping () -> Void = {},
        onEndEditing: @escaping () -> Void = {}
    ) {
        self.init(
            title,
            value: Parser.multiselectValue(sources: sources, value: value),
            onChange: onChange,
            in: range,
            errorMessage: errorMessage,
            onBeginEditing: onBeginEditing,
            onEndEditing: onEndEditing
        )
    }

    public var body: some View {
        VStack {
            HStack {
                Slider(
                    value: $number,
                    in: range,
                    step: 0.5,
                    onEditingChanged: { isEditing in
                        if isEditing {
                            onBeginEditing()
                        } else {
                            onEndEditing()
                        }
                    }
                )
                .controlSize(.mini)
                .frame(minWidth: 80)
                
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
            
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.red)
            }
        }
        .onChange(of: value.value, initial: true) { oldValue, newValue in
            text = Parser.formatValue(newValue)
            number = Parser.doubleValue(newValue)
        }
        .onChange(of: text) { oldValue, newValue in
            guard newValue != oldValue else {
                return
            }
            
            switch Parser.parseValue(newValue) {
            case let .success(newValue):
                if Parser.hasChanged(value.value, newValue) {
                    beginTextEditingIfNecessary()
                    value.onChange(newValue)
                }
                errorMessage = nil
            case let .failure(error):
                errorMessage = error.message
            }
        }
        .onChange(of: number) { oldValue, newValue in
            guard !newValue.isClose(to: oldValue, threshold: 1e-6) else {
                return
            }
            
            let parsedValue = Parser.fromDoubleValue(newValue, existing: value.value)
            if Parser.hasChanged(value.value, parsedValue) {
                value.onChange(parsedValue)
            }
            text = Parser.formatValue(parsedValue)
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

private extension ValueSliderField {
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
