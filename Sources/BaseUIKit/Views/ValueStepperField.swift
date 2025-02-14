import SwiftUI

public struct ValueStepperField<Parser: SliderFieldParser>: View {
    private let title: String
    private let value: Binding<Parser.Value>
    private let step: Double
    private let onBeginEditing: () -> Void
    private let onEndEditing: () -> Void
    @State private var errorMessage: String?
    @State private var text: String = ""
    @State private var number: Double = 0.0
    @State private var isTextEditing = false
    @FocusState private var isFocused: Bool

    public init(
        _ title: String,
        value: Binding<Parser.Value>,
        step: Double,
        errorMessage: String? = nil,
        onBeginEditing: @escaping () -> Void = {},
        onEndEditing: @escaping () -> Void = {}
    ) {
        self.title = title
        self.value = value
        self.step = step
        self.onBeginEditing = onBeginEditing
        self.onEndEditing = onEndEditing
        self.errorMessage = errorMessage
    }
    
    public init<C: RandomAccessCollection & Sendable>(
        _ title: String,
        sources: C,
        value: KeyPath<C.Element, Binding<Parser.Value>> & Sendable,
        step: Double,
        errorMessage: String? = nil,
        onBeginEditing: @escaping () -> Void = {},
        onEndEditing: @escaping () -> Void = {}
    ) {
        self.init(
            title,
            value: Parser.multiselectBinding(sources: sources, value: value),
            step: step,
            errorMessage: errorMessage,
            onBeginEditing: onBeginEditing,
            onEndEditing: onEndEditing
        )
    }

    public var body: some View {
        VStack {
                Stepper(
                    value: $number,
                    step: step,
                    label: {
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
            
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.red)
            }
        }
        .onChange(of: value.wrappedValue, initial: true) { oldValue, newValue in
            text = Parser.formatValue(newValue)
            number = Parser.doubleValue(newValue)
        }
        .onChange(of: text) { oldValue, newValue in
            guard newValue != oldValue else {
                return
            }
            
            switch Parser.parseValue(newValue) {
            case let .success(newValue):
                if Parser.hasChanged(value.wrappedValue, newValue) {
                    beginTextEditingIfNecessary()
                    value.wrappedValue = newValue
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
            
            let parsedValue = Parser.fromDoubleValue(newValue, existing: value.wrappedValue)
            if Parser.hasChanged(value.wrappedValue, parsedValue) {
                value.wrappedValue = parsedValue
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
