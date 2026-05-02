import BaseKit
import SwiftUI

public extension View {
    /// Presents the platform's native color picker — `NSColorPanel` on
    /// macOS, `UIColorPickerViewController` (as a popover) on iOS — when
    /// `isPresented` becomes `true`. The picker writes user-selected
    /// colors back through `color` continuously while open. The two
    /// callbacks bracket the editing session: `onBeginEditing` fires
    /// once when the picker opens, `onEndEditing` once when it closes,
    /// suitable for opening / completing a command stream.
    ///
    /// On iOS, the popover anchors to the view this modifier is applied
    /// to; on macOS, `NSColorPanel` is a free-floating window and the
    /// anchor is ignored (apply this to any visible view in the active
    /// window).
    func presentColorPicker(
        isPresented: Binding<Bool>,
        color: Binding<BaseKit.Color>,
        onBeginEditing: @escaping () -> Void = {},
        onEndEditing: @escaping () -> Void = {}
    ) -> some View {
        modifier(
            BindingColorPickerModifier(
                isPresented: isPresented,
                color: color,
                onBeginEditing: onBeginEditing,
                onEndEditing: onEndEditing
            )
        )
    }
}

private struct BindingColorPickerModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var color: BaseKit.Color
    let onBeginEditing: () -> Void
    let onEndEditing: () -> Void

    func body(content: Content) -> some View {
        // Bridge to the internal SmartBind/Callback-based modifier. The
        // SmartBind reads the binding's current value and writes back
        // through its onChange — keeping the public API in plain SwiftUI
        // types while reusing the existing platform implementations.
        let bind = SmartBind(color, { color = $0 })
        return content.presentColorPicker(
            isPresented: $isPresented,
            color: bind,
            onBeginEditing: Callback(onBeginEditing),
            onEndEditing: Callback(onEndEditing)
        )
    }
}
