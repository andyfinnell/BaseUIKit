import SwiftUI

public struct PopOverSliderField<Parser: SliderFieldParser>: View {
    private let title: String
    private let value: Binding<Parser.Value>
    private let range: ClosedRange<Double>
    private let onBeginEditing: () -> Void
    private let onEndEditing: () -> Void
    @State private var text: String = ""
    @State private var errorMessage: String? = nil
    @State private var isShowing = false
    
    public init(
        _ title: String,
        value: Binding<Parser.Value>,
        in range: ClosedRange<Double>,
        errorMessage: String? = nil,
        onBeginEditing: @escaping () -> Void = {},
        onEndEditing: @escaping () -> Void = {}
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
        value: KeyPath<C.Element, Binding<Parser.Value>> & Sendable,
        in range: ClosedRange<Double>,
        errorMessage: String? = nil,
        onBeginEditing: @escaping () -> Void = {},
        onEndEditing: @escaping () -> Void = {}
    ) {
        self.init(
            title,
            value: Parser.multiselectBinding(sources: sources, value: value),
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
                    number: Parser.doubleValue(value.wrappedValue),
                    text: $text,
                    range: range,
                    onBeginEditing: onBeginEditing,
                    onEndEditing: onEndEditing,
                    onChange: { newValue in
                        value.wrappedValue = Parser.fromDoubleValue(newValue, existing: value.wrappedValue)
                    },
                    toText: { newValue in
                        Parser.formatValue(Parser.fromDoubleValue(newValue, existing: value.wrappedValue))
                    }
                )
            }
            
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
        .frame(minWidth: 200)
        .padding()
        .onChange(of: number) { oldValue, newValue in
            guard newValue != oldValue else {
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
        .frame(minWidth: 200)
        .padding()
        .onChange(of: number) { oldValue, newValue in
            guard newValue != oldValue else {
                return
            }
            
            onChange(newValue)
            text = toText(newValue)
        }
#endif
    }
}
