import Foundation
import SwiftUI

public extension View {
    @MainActor
    func dialog(
        isVisible: Bool,
        title: String,
        cancelTitle: String = "Cancel",
        cancelEnabled: Bool = true,
        okTitle: String = "OK",
        okEnabled: Bool = true,
        onSubmit: @escaping () -> Void
    ) -> some View {
        modifier(
            DialogModifier(
                isVisible: isVisible,
                title: title,
                cancelTitle: cancelTitle,
                cancelEnabled: cancelEnabled,
                okTitle: okTitle,
                okEnabled: okEnabled,
                onSubmit: onSubmit
            )
        )
    }
}

@MainActor
struct DialogModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    let isVisible: Bool
    let title: String
    let cancelTitle: String
    let cancelEnabled: Bool
    let okTitle: String
    let okEnabled: Bool
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
                            .disabled(!cancelEnabled)
                    }
                    
                    ToolbarItem(placement: .confirmationAction) {
                        Button(okTitle) {
                            onSubmit()
                        }.keyboardShortcut(.defaultAction)
                            .disabled(!okEnabled)
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
