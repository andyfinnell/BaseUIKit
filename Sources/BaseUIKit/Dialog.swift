import Foundation
import SwiftUI

public extension View {
    @MainActor
    func dialog(
        isVisible: Bool,
        title: String,
        cancelTitle: String = "Cancel",
        okTitle: String = "OK",
        onSubmit: @escaping () -> Void
    ) -> some View {
        modifier(DialogModifier(isVisible: isVisible, title: title, cancelTitle: cancelTitle, okTitle: okTitle, onSubmit: onSubmit))
    }
}

@MainActor
struct DialogModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    let isVisible: Bool
    let title: String
    let cancelTitle: String
    let okTitle: String
    let onSubmit: () -> Void
    
    func body(content: Content) -> some View {
        navigationContainer {
            content
                .titled(title)
                .onChange(of: isVisible, { wasVisible, nowVisible in
                    if wasVisible && !nowVisible {
                        dismiss()
                    }
                })
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(cancelTitle) {
                            dismiss()
                        }.keyboardShortcut(.cancelAction)
                    }
                    
                    ToolbarItem(placement: .confirmationAction) {
                        Button(okTitle) {
                            onSubmit()
                        }.keyboardShortcut(.defaultAction)
                    }
                }
        }
    }
}

private extension DialogModifier {
    @ViewBuilder
    func navigationContainer<O: View>(@ViewBuilder modifiers: () -> O) -> some View {
        #if os(macOS)
        modifiers()
        #else
        NavigationStack {
            modifiers()
        }
        #endif
    }
}

private extension View {
    func titled(_ title: String) -> some View {
        #if os(macOS)
        VStack(alignment: .leading) {
            Text(title)
                .font(.largeTitle)
                .padding()
            
            Divider()
            
            self
        }
        #else
        navigationTitle(title)
        #endif
    }
}
