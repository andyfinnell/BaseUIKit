import SwiftUI

public struct NumericField: View {
    private static let numberFormater: NumberFormatter = {
       let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
    let title: String
    let value: Binding<Double>
    let errorMessage: String?
    
    public init(
        _ title: String,
        value: Binding<Double>,
        errorMessage: String? = nil
    ) {
        self.title = title
        self.value = value
        self.errorMessage = errorMessage
    }
    
    public var body: some View {
        VStack {
            TextField(
                title,
                value: value,
                formatter: NumericField.numberFormater,
                prompt: Text(title)
            )
            #if os(iOS)
            .keyboardType(.decimalPad)
            .textFieldStyle(.roundedBorder)
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
    }
}
