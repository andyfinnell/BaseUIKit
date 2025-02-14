import Foundation
import SwiftUI
import BaseKit

public struct AngleFieldParser: FieldParser {
    private static let numberFormater: NumberFormatter = {
       let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.positiveSuffix = "º"
        formatter.minimum = 0
        formatter.maximum = 360
        return formatter
    }()
    
    public static func parseValue(_ text: String) -> Result<BaseKit.Angle, FieldParserError> {
        guard let parsedNumber = numberFormater.number(from: text) else {
            return Result.failure(FieldParserError(message: "Invalid angle"))
        }
        let number = parsedNumber.doubleValue
        return Result.success(BaseKit.Angle(degrees: number))
    }
    
    public static func formatValue(_ value: BaseKit.Angle) -> String {
        numberFormater.string(for: value.degrees) ?? ""
    }
    
    public static func hasChanged(_ old: BaseKit.Angle, _ new: BaseKit.Angle) -> Bool {
        old != new
    }
    
    public static func multiselectBinding<C: RandomAccessCollection & Sendable>(
        sources: C,
        value: KeyPath<C.Element, Binding<BaseKit.Angle>> & Sendable
    ) -> Binding<BaseKit.Angle> {
        Binding<BaseKit.Angle>(sources: sources, value: value)
    }
}

public struct AngleField: View {
    private let title: String
    private let value: Binding<AngleFieldParser.Value>
    private let onBeginEditing: () -> Void
    private let onEndEditing: () -> Void
    @State private var text: String = ""
    @State private var errorMessage: String? = nil
    @State private var isShowing = false
    @State private var isTextEditing = false
    @FocusState private var isFocused: Bool
    
    public init(
        _ title: String,
        value: Binding<AngleFieldParser.Value>,
        errorMessage: String? = nil,
        onBeginEditing: @escaping () -> Void = {},
        onEndEditing: @escaping () -> Void = {}
    ) {
        self.title = title
        self.value = value
        self.onBeginEditing = onBeginEditing
        self.onEndEditing = onEndEditing
    }

    public init<C: RandomAccessCollection & Sendable>(
        _ title: String,
        sources: C,
        value: KeyPath<C.Element, Binding<AngleFieldParser.Value>> & Sendable,
        errorMessage: String? = nil,
        onBeginEditing: @escaping () -> Void = {},
        onEndEditing: @escaping () -> Void = {}
    ) {
        self.init(
            title,
            value: AngleFieldParser.multiselectBinding(sources: sources, value: value),
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
                .popover(isPresented: $isShowing) {
                    PopOverAngleDial(
                        angle: value.wrappedValue,
                        text: $text,
                        onBeginEditing: onBeginEditing,
                        onEndEditing: onEndEditing,
                        onChange: { newValue in
                            let parsedValue = newValue
                            if AngleFieldParser.hasChanged(value.wrappedValue, parsedValue) {
                                value.wrappedValue = parsedValue
                            }
                        },
                        toText: { newValue in
                            AngleFieldParser.formatValue(newValue)
                        }
                    )
                }
            }
            
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.red)
            }
        }
        .onChange(of: value.wrappedValue, initial: true) { oldValue, newValue in
            text = AngleFieldParser.formatValue(newValue)
        }
        .onChange(of: text) { oldValue, newValue in
            guard newValue != oldValue else {
                return
            }
            
            switch AngleFieldParser.parseValue(newValue) {
            case let .success(newValue):
                if AngleFieldParser.hasChanged(value.wrappedValue, newValue) {
                    beginTextEditingIfNecessary()
                    value.wrappedValue = newValue
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

private extension AngleField {
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

struct PopOverAngleDial: View {
    @State var angle: BaseKit.Angle
    @Binding var text: String
    let onBeginEditing: () -> Void
    let onEndEditing: () -> Void
    let onChange: (BaseKit.Angle) -> Void
    let toText: (BaseKit.Angle) -> String
    
    var body: some View {
#if os(macOS)
        AngleDial(
            angle: $angle,
            onBeginEditing: onBeginEditing,
            onEndEditing: onEndEditing
        )
        .onChange(of: angle) { oldValue, newValue in
            guard newValue != oldValue else {
                return
            }
            
            onChange(newValue)
            text = toText(newValue)
        }
#endif
#if os(iOS)
        AngleDial(
            angle: $angle,
            onBeginEditing: onBeginEditing,
            onEndEditing: onEndEditing
        )
        .onChange(of: angle) { oldValue, newValue in
            guard newValue != oldValue else {
                return
            }
            
            onChange(newValue)
            text = toText(newValue)
        }
#endif
    }
}

struct AngleFieldPreview: View {
    @State var angle: BaseKit.Angle = .init(degrees: 90)
    
    var body: some View {
        AngleField("Angle", value: $angle)
    }
}

#Preview {
    VStack {
        HStack {
            AngleFieldPreview()
                .padding()
            
            Spacer()
        }
        
        Spacer()
    }
}
