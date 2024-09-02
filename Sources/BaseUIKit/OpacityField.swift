import SwiftUI

public struct OpacityField: View {
    private var opacity: Binding<Double>
    @State private var isShowing = false
    
    public init(value: Binding<Double>) {
        self.opacity = value
    }
    
    public var body: some View {
        HStack {
            TextField(
                "Opacity",
                text: Binding<String>(
                    get: {
                        formatValue(opacity.wrappedValue)
                    },
                    set: {
                        opacity.wrappedValue = parseValue($0)
                    }
                )
            )
            #if os(macOS)
            .textFieldStyle(.squareBorder)
            #endif
            #if os(iOS)
            .keyboardType(.decimalPad)
            #endif
            .autocorrectionDisabled(true)
            .multilineTextAlignment(.leading)
            .frame(width: 80)
            .labelsHidden()
            
            Button(action: {
                isShowing.toggle()
            }, label: {
                Image(systemName: "chevron.up.chevron.down")
            })
            #if os(macOS)
            .popover(isPresented: $isShowing) {
                Slider(
                    value: opacity,
                    in: 0...1
                )
                .controlSize(.mini)
                .frame(minWidth: 200)
                .padding()
            }
            #endif
        }
        #if os(iOS)
        .popover(isPresented: $isShowing) {
            Slider(
                value: opacity,
                in: 0...1
            )
            .controlSize(.mini)
            .frame(minWidth: 200)
            .padding()
        }
        #endif
    }
}

private extension OpacityField {
    private static let numberFormater: NumberFormatter = {
       let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    func formatValue(_ opacity: Double) -> String {
        OpacityField.numberFormater.string(for: opacity) ?? "0"
    }
    
    func parseValue(_ value: String) -> Double {
        let number = Double(value) ?? 0.0
        return min(1, max(0, number))
    }
}

private struct OpacityFieldPreview: View {
    @State private var opacity = 1.0
    
    var body: some View {
        OpacityField(value: $opacity)
    }
}

#Preview {
    OpacityFieldPreview()
        .frame(maxWidth: 280)
        .padding()
}
