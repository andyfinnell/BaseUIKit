import Foundation
import SwiftUI

public extension View {
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

struct DialogModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    let isVisible: Bool
    let title: String
    let cancelTitle: String
    let okTitle: String
    let onSubmit: () -> Void
    
    func body(content: Content) -> some View {
        NavigationStack {
            content
                .navigationTitle(title)
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
