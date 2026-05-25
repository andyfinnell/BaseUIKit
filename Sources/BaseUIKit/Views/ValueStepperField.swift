import SwiftUI

public struct ValueStepperField<Parser: SliderFieldParser>: View {
    private let title: String
    private let value: SmartBind<Parser.Value, ExtraEmpty>
    private let step: Double
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
        step: Double,
        errorMessage: String? = nil,
        onBeginEditing: @escaping () -> Void = {},
        onEndEditing: @escaping () -> Void = {}
    ) {
        self.title = title
        self.value = SmartBind(value, onChange)
        self.step = step
        self.onBeginEditing = Callback(onBeginEditing)
        self.onEndEditing = Callback(onEndEditing)
        self.errorMessage = errorMessage
    }

    public init(
        _ title: String,
        value: Binding<Parser.Value>,
        step: Double,
        errorMessage: String? = nil,
        onBeginEditing: @escaping () -> Void = {},
        onEndEditing: @escaping () -> Void = {}
    ) {
        self.init(title, value: value.wrappedValue, onChange: { value.wrappedValue = $0 }, step: step, errorMessage: errorMessage, onBeginEditing: onBeginEditing, onEndEditing: onEndEditing)
    }
    
    public var body: some View {
        VStack {
                Stepper(
                    value: $number,
                    step: step,
                    label: {
                        TextField(
                            text: $text,
                            prompt: Text(promptText),
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

                    },
                    onEditingChanged: { isEditing in
                        if isEditing {
                            onBeginEditing()
                        } else {
                            onEndEditing()
                        }
                    }
                )
                .fixedSize()
                .disabled(Parser.isMixedSentinel(value.value))

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.red)
            }
        }
        .onChange(of: value.value, initial: true) { oldValue, newValue in
            text = expectedTextForCurrentValue(newValue)
            number = Parser.doubleValue(newValue)
        }
        .onChange(of: text) { oldValue, newValue in
            guard newValue != oldValue else {
                return
            }
            // Skip the write-back when the text update was driven by a
            // change to `value.value` rather than user typing — detected
            // by `text` matching what we'd render programmatically.
            // See the longer rationale in `InlineSliderField` and the
            // AppearancePanel mixed-opacity regression test.
            if newValue == expectedTextForCurrentValue(value.value) {
                errorMessage = nil
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
            // Skip the write-back when the stepper state was driven by a
            // change to `value.value` rather than the user clicking the
            // stepper. Detection: `number` matches `doubleValue(value.value)`.
            // See `InlineSliderField` for the longer rationale and the
            // AppearancePanel mixed-opacity regression test.
            if newValue.isClose(
                to: Parser.doubleValue(value.value), threshold: 1e-6)
            {
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

private extension ValueStepperField {
    func expectedTextForCurrentValue(_ value: Parser.Value) -> String {
        Parser.isMixedSentinel(value) ? "" : Parser.formatValue(value)
    }

    var promptText: String {
        Parser.isMixedSentinel(value.value) ? "Mixed" : title
    }

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
