import SwiftUI

public struct PopOverSliderField<Parser: SliderFieldParser>: View {
    private let title: String
    private let value: Parser.Value
    private let onChange: (Parser.Value) -> Void
    private let range: ClosedRange<Double>
    private let onBeginEditing: () -> Void
    private let onEndEditing: () -> Void
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
        self.value = value
        self.onChange = onChange
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
                    number: Parser.doubleValue(value),
                    text: $text,
                    range: range,
                    onBeginEditing: onBeginEditing,
                    onEndEditing: onEndEditing,
                    onChange: { newValue in
                        let parsedValue = Parser.fromDoubleValue(newValue, existing: value)
                        if Parser.hasChanged(value, parsedValue) {
                            onChange(parsedValue)
                        }
                    },
                    toText: { newValue in
                        Parser.formatValue(Parser.fromDoubleValue(newValue, existing: value))
                    }
                )
            }
            
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
    let onBeginEditing: () -> Void
    let onEndEditing: () -> Void
    let onChange: (Double) -> Void
    let toText: (Double) -> String
    
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
