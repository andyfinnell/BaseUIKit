import SwiftUI
import BaseKit
import BaseUIKit

struct ColorChip: View {
    @Binding var color: BaseKit.Color
    @State private var isPresenting = false
    
    var body: some View {
        VStack(spacing: 0) {
            Triangle()
                .fill(Color.gray)
                .frame(width: ColorChip.width, height: ColorChip.triangleHeight)
            
            colorValue
                .frame(width: ColorChip.width, height: ColorChip.height, alignment: .center)
                .overlay(Rectangle().stroke(Color.gray, style: StrokeStyle(lineWidth: 1)))
                .presentColorPicker(isPresented: $isPresenting, color: $color)
        }.onTapGesture {
            isPresenting.toggle()
        }
    }
    
    static let bodyHeight: CGFloat = height
    #if os(macOS)
    static let centerYOffset: CGFloat = 3.0
    #else
    static let centerYOffset: CGFloat = 9.0
    #endif
    
#if os(macOS)
static let width: CGFloat = 16.0
static let height: CGFloat = 16.0
static let triangleHeight: CGFloat = 10.0
#else
static let width: CGFloat = 24
static let height: CGFloat = 24
static let triangleHeight: CGFloat = height / 2.0
#endif

}

private extension ColorChip {
    
    @ViewBuilder
    var colorValue: SwiftUI.Color {
        color.swiftUI
    }
}

#if canImport(AppKit)
import AppKit

extension View {
    func presentColorPicker(isPresented: Binding<Bool>, color: Binding<BaseKit.Color>) -> some View {
        modifier(ColorPanelModifier(color: color, isPresented: isPresented))
    }
}

struct ColorPanelModifier: ViewModifier {
    @State private var coordinator = ColorPanelCoordinator()
    @Binding var color: BaseKit.Color
    @Binding var isPresented: Bool
    
    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { oldValue, newValue in
                guard oldValue != newValue else {
                    return
                }
                if newValue {
                    coordinator.present(
                        initialColor: color,
                        onDismiss: {
                            isPresented = false
                        },
                        onChange: { newColor in
                            color = newColor
                        }
                    )
                }
            }
    }
}

@MainActor
final class ColorPanelCoordinator: NSObject {
    private var onChange: ((BaseKit.Color) -> Void)? = nil
    private var onDismiss: (() -> Void)? = nil

    override init() {
        super.init()
    }
    
    func present(
        initialColor: BaseKit.Color,
        onDismiss: @escaping () -> Void,
        onChange: @escaping (BaseKit.Color) -> Void
    ) {
        self.onChange = onChange
        self.onDismiss = onDismiss
        
        let panel = NSColorPanel.shared
        panel.isContinuous = true
        panel.setTarget(self)
        panel.setAction(#selector(onColorChanged(_:)))
        panel.delegate = self

        // Only set once we've pointed to ourselves
        panel.color = initialColor.native

        NSApp.orderFrontColorPanel(panel)
    }
}

private extension ColorPanelCoordinator {
    @objc
    func onColorChanged(_ sender: Any?) {
        let panel = NSColorPanel.shared
        let color = BaseKit.Color(native: panel.color)
        onChange?(color)
    }
}

extension ColorPanelCoordinator: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        
        let panel = NSColorPanel.shared
        panel.setTarget(nil)
        panel.delegate = nil

        onDismiss?()
        
        onDismiss = nil
        onChange = nil
    }
}

#endif

#if canImport(UIKit)
import UIKit

extension View {
    func presentColorPicker(isPresented: Binding<Bool>, color: Binding<BaseKit.Color>) -> some View {
        modifier(ColorPanelModifier(color: color, isPresented: isPresented))
    }
}

struct ColorPanelModifier: ViewModifier {
    @Binding var color: BaseKit.Color
    @Binding var isPresented: Bool
    
    func body(content: Content) -> some View {
        content
            .popover(isPresented: $isPresented) {
                ColorPickerViewControllerRepresentable(
                    color: color,
                    onChange: { newColor in
                        color = newColor
                    },
                    onDismiss: {
                        isPresented = false
                    }
                )
            }
    }
}

struct ColorPickerViewControllerRepresentable: UIViewControllerRepresentable {
    var color: BaseKit.Color
    var onChange: ((BaseKit.Color) -> Void)? = nil
    var onDismiss: (() -> Void)? = nil

    final class Coordinator: NSObject, UIColorPickerViewControllerDelegate {
        var onChange: ((BaseKit.Color) -> Void)? = nil
        var onDismiss: (() -> Void)? = nil

        override init() {
            super.init()
        }
        
        func colorPickerViewController(_ viewController: UIColorPickerViewController, didSelect color: UIColor, continuously: Bool) {
            onChange?(BaseKit.Color(native: color))
        }

        func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
            onDismiss?()
        }
    }
    
    @MainActor
    func makeUIViewController(context: Context) -> UIColorPickerViewController {
        let viewController = UIColorPickerViewController()
        viewController.delegate = context.coordinator
        context.coordinator.onChange = onChange
        context.coordinator.onDismiss = onDismiss
        viewController.selectedColor = color.native
        viewController.modalPresentationStyle = .popover
        return viewController
    }

    @MainActor 
    func updateUIViewController(_ uiViewController: UIColorPickerViewController, context: Context) {
        context.coordinator.onChange = onChange
        context.coordinator.onDismiss = onDismiss
        uiViewController.selectedColor = color.native
    }
    
    @MainActor 
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    @MainActor
    func sizeThatFits(_ proposal: ProposedViewSize, uiViewController: UIColorPickerViewController, context: Context) -> CGSize? {
        CGSize(width: 375, height: 615)
    }
}

#endif

struct ColorChipPreview: View {
    @State var color = BaseKit.Color.black
    
    var body: some View {
        ColorChip(color: $color)
    }
}

#Preview {
    ColorChipPreview()
        .padding()
}