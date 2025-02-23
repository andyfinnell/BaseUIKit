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
    
    public static func multiselectValue<C: RandomAccessCollection & Sendable>(
        sources: C,
        value: KeyPath<C.Element, BaseKit.Angle> & Sendable
    ) -> BaseKit.Angle {
        sources.reduce(BaseKit.Angle?.none) { sum, element in
            let elementValue = element[keyPath: value]
            if sum == nil {
                return elementValue
            } else if let sum, sum == elementValue {
                return sum
            } else {
                return BaseKit.Angle.zero
            }
        } ?? BaseKit.Angle.zero
    }
}

public struct AngleField: View {
    private let title: String
    private let value: AngleFieldParser.Value
    private let onChange: (AngleFieldParser.Value) -> Void
    private let onBeginEditing: () -> Void
    private let onEndEditing: () -> Void
    @State private var text: String = ""
    @State private var errorMessage: String? = nil
    @State private var isShowing = false
    @State private var isTextEditing = false
    @FocusState private var isFocused: Bool
    
    public init(
        _ title: String,
        value: AngleFieldParser.Value,
        onChange: @escaping (AngleFieldParser.Value) -> Void,
        errorMessage: String? = nil,
        onBeginEditing: @escaping () -> Void = {},
        onEndEditing: @escaping () -> Void = {}
    ) {
        self.title = title
        self.value = value
        self.onChange = onChange
        self.onBeginEditing = onBeginEditing
        self.onEndEditing = onEndEditing
    }

//    public init<C: RandomAccessCollection & Sendable>(
//        _ title: String,
//        sources: C,
//        value: KeyPath<C.Element, Binding<AngleFieldParser.Value>> & Sendable,
//        errorMessage: String? = nil,
//        onBeginEditing: @escaping () -> Void = {},
//        onEndEditing: @escaping () -> Void = {}
//    ) {
//        self.init(
//            title,
//            value: AngleFieldParser.multiselectBinding(sources: sources, value: value),
//            errorMessage: errorMessage,
//            onBeginEditing: onBeginEditing,
//            onEndEditing: onEndEditing
//        )
//    }

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
                        angle: value,
                        onBeginEditing: onBeginEditing,
                        onEndEditing: onEndEditing,
                        onChange: { newValue in
                            if AngleFieldParser.hasChanged(value, newValue) {
                                onChange(newValue)
                            }
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
        .onChange(of: value, initial: true) { oldValue, newValue in
            text = AngleFieldParser.formatValue(newValue)
        }
        .onChange(of: text) { oldValue, newValue in
            guard newValue != oldValue else {
                return
            }
            
            switch AngleFieldParser.parseValue(newValue) {
            case let .success(newValue):
                if AngleFieldParser.hasChanged(value, newValue) {
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
    let angle: BaseKit.Angle
    let onBeginEditing: () -> Void
    let onEndEditing: () -> Void
    let onChange: (BaseKit.Angle) -> Void
    
    var body: some View {
#if os(macOS)
        AngleDial(
            angle: angle,
            onChange: onChange,
            onBeginEditing: onBeginEditing,
            onEndEditing: onEndEditing
        )
#endif
#if os(iOS)
        AngleDial(
            angle: angle,
            onChange: onChange,
            onBeginEditing: onBeginEditing,
            onEndEditing: onEndEditing
        )
#endif
    }
}

struct AngleFieldPreview: View {
    @State var angle: BaseKit.Angle = .init(degrees: 90)
    
    var body: some View {
        AngleField("Angle", value: angle, onChange: { angle = $0 })
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
