import SwiftUI

public struct PopOverSliderField<Parser: SliderFieldParser>: View {
    private let title: String
    private let value: SmartBind<Parser.Value>
    private let range: ClosedRange<Double>
    private let onBeginEditing: Callback<Void>
    private let onEndEditing: Callback<Void>
    @State private var text: String = ""
    @State private var errorMessage: String? = nil
    @State private var isShowing = false
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
    }

    init(
        _ title: String,
        value: SmartBind<Parser.Value>,
        in range: ClosedRange<Double>,
        errorMessage: String? = nil,
        onBeginEditing: Callback<Void>,
        onEndEditing: Callback<Void>
    ) {
        self.title = title
        self.value = value
        self.range = range
        self.onBeginEditing = onBeginEditing
        self.onEndEditing = onEndEditing
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
                
                Button(action: {
                    isShowing.toggle()
                }, label: {
                    Image(systemName: "chevron.up.chevron.down")
                })
            }
            .popover(isPresented: $isShowing) {
                PopOverSlider(
                    number: Parser.doubleValue(value.value),
                    text: $text,
                    range: range,
                    onBeginEditing: onBeginEditing,
                    onEndEditing: onEndEditing,
                    onChange: Callback({ newValue in
                        let parsedValue = Parser.fromDoubleValue(newValue, existing: value.value)
                        if Parser.hasChanged(value.value, parsedValue) {
                            value.onChange(parsedValue)
                        }
                    }),
                    toText: Call({ newValue in
                        Parser.formatValue(Parser.fromDoubleValue(newValue, existing: value.value))
                    })
                )
            }
            
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.red)
            }
        }
        .onChange(of: value.value, initial: true) { oldValue, newValue in
            text = Parser.formatValue(newValue)
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

private extension PopOverSliderField {
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

struct PopOverSlider: View {
    @State var number: Double
    @Binding var text: String
    let range: ClosedRange<Double>
    let onBeginEditing: Callback<Void>
    let onEndEditing: Callback<Void>
    let onChange: Callback<Double>
    let toText: Call<Double, String>
    
    var body: some View {
#if os(macOS)
        Slider(
            value: $number,
            in: range,
            step: computeStep(fromRange: range),
            onEditingChanged: { isEditing in
                if isEditing {
                    onBeginEditing()
                } else {
                    onEndEditing()
                }
            }
        )
        .controlSize(.mini)
        .frame(minWidth: 200)
        .padding()
        .onChange(of: number) { oldValue, newValue in
            guard !newValue.isClose(to: oldValue, threshold: 1e-6) else {
                return
            }
            
            onChange(newValue)
            text = toText(newValue)
        }
#endif
#if os(iOS)
        Slider(
            value: $number,
            in: range,
            step: computeStep(fromRange: range),
            onEditingChanged: { isEditing in
                if isEditing {
                    onBeginEditing()
                } else {
                    onEndEditing()
                }
            }
        )
        .controlSize(.mini)
        .frame(minWidth: 200)
        .padding()
        .onChange(of: number) { oldValue, newValue in
            guard !newValue.isClose(to: oldValue, threshold: 1e-6) else {
                return
            }

            onChange(newValue)
            text = toText(newValue)
        }
#endif
    }
}

private func computeStep(fromRange range: ClosedRange<Double>) -> Double {
    (range.upperBound - range.lowerBound) / 200.0
}
