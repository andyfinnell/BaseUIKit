import SwiftUI
import BaseKit

public struct ColorWell: View {
    @Environment(\.self) private var environment
    private let title: String
    private let colors: [Binding<BaseKit.Color>]
    private let supportsOpacity: Bool
    @State private var isPresenting = false
    
    public init<C: RandomAccessCollection & Sendable>(
        _ title: String,
        sources: C,
        color: KeyPath<C.Element, Binding<BaseKit.Color>> & Sendable,
        supportsOpacity: Bool = true
    ) {
        self.title = title
        self.colors = sources.map { $0[keyPath: color] }
        self.supportsOpacity = supportsOpacity
    }
    
    public init(_ title: String, color: Binding<BaseKit.Color>, supportsOpacity: Bool = true) {
        self.title = title
        self.colors = [color]
        self.supportsOpacity = supportsOpacity
    }
    
    public var body: some View {
        if let color = colors.only {
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
        } else {
            HStack {
                Text(title)
                
                #if os(iOS)
                Spacer()
                #endif
                
                Button(action: {
                    isPresenting.toggle()
                }) {
#if os(macOS)
                    MulticolorView(
                        colors: colors.map { $0.wrappedValue
                        },
                        width: 36,
                        height: 16)
                    .clipShape(RoundedRectangle(cornerRadius: 2))

#else
                    MulticolorView(
                        colors: colors.map { $0.wrappedValue
                        },
                        width: 26,
                        height: 26)
                    .clipShape(Circle())
#endif
                }
                .buttonStyle(ColorWellButtonStyle())
                .focusEffectDisabled()
                .presentColorPicker(isPresented: $isPresenting, color: presentedColor)
            }
        }
    }
}

private extension ColorWell {
    var presentedColor: Binding<BaseKit.Color> {
        Binding<BaseKit.Color>(
            get: {
                colors.first?.wrappedValue ?? BaseKit.Color.black
            },
            set: { newValue, transaction in
                for color in colors {
                    color.wrappedValue = newValue
                }
            }
        )
    }
}

struct ColorWellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let isHighlighted = configuration.isPressed
        #if os(macOS)
        return configuration.label
            .padding(.all, 4)
            .background(isHighlighted ? Color.systemFill : Color.systemGray)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        #else
        return configuration.label
            .padding(.all, 3)
            .background(ColorWellBorder())
            .brightness(isHighlighted ? 0.1 : 0.0)
        #endif
    }
}

struct ColorWellBorder: View {
    var body: some View {
        Circle()
            .stroke(
                AngularGradient(stops: [
                    stop(0.0),
                    stop(0.125),
                    stop(0.25),
                    stop(0.375),
                    stop(0.5),
                    stop(0.625),
                    stop(0.75),
                    stop(0.875),
                    stop(1.0),
                ], center: .center),
                lineWidth: 3
            )
    }
    
    private func stop(_ location: CGFloat) -> Gradient.Stop {
        Gradient.Stop(color: Color(hue: 1.0 - location, saturation: 1.0, brightness: 1.0), location: location)
    }
}

struct PreviewColorWell: View {
    @State private var colors: [BaseKit.Color] = [
        .blue, .red, .yellow, .purple, .orange, .green
    ]
    
    var body: some View {
        ColorWell("Color", sources: $colors, color: \.self)
    }
}

struct PreviewSingleColorWell: View {
    @State private var color = BaseKit.Color.blue
    
    var body: some View {
        ColorWell("Color", color: $color)
    }
}

#Preview {
    VStack {
        HStack {
            PreviewColorWell()
                .padding()
                .frame(maxWidth: 300)

            Spacer()
        }
        
        HStack {
            PreviewSingleColorWell()
                .padding()
                .frame(maxWidth: 300)
            
            Spacer()
        }
        
        Spacer()
    }
}
