import SwiftUI
import BaseKit

public struct ColorWell: View {
    @Environment(\.self) private var environment
    private let title: String
    private let color: Binding<BaseKit.Color>
    private let supportsOpacity: Bool
    
    public init(_ title: String, color: Binding<BaseKit.Color>, supportsOpacity: Bool = true) {
        self.title = title
        self.color = color
        self.supportsOpacity = supportsOpacity
    }
    
    public var body: some View {
        ColorPicker(
            title,
            selection: Binding<SwiftUI.Color>(
                get: {
                    SwiftUI.Color(
                        red: color.wrappedValue.red,
                        green: color.wrappedValue.green,
                        blue: color.wrappedValue.blue,
                        opacity: color.wrappedValue.alpha
                    )
                },
                set: { newColor in
                    let resolvedColor = newColor.resolve(in: environment)
                    color.wrappedValue = BaseKit.Color(
                        red: Double(resolvedColor.red),
                        green: Double(resolvedColor.green),
                        blue: Double(resolvedColor.blue),
                        alpha: Double(resolvedColor.opacity)
                    )
                }
            ),
            supportsOpacity: supportsOpacity
        )
    }
}
