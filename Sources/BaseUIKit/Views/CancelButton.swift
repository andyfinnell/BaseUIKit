import SwiftUI

public struct CancelButton: View {
    @Environment(\.dismiss) private var dismiss
    private let title: String
    private let isEnabled: Bool
    
    public init(_ title: String = "Cancel", isEnabled: Bool = true) {
        self.title = title
        self.isEnabled = isEnabled
    }
    
    public var body: some View {
        Button(title) {
            dismiss()
        }
        .keyboardShortcut(.cancelAction)
        .disabled(!isEnabled)
    }
}

public struct CancelToolbarItem: ToolbarContent {
    private let title: String
    private let isEnabled: Bool
    
    public init(_ title: String = "Cancel", isEnabled: Bool = true) {
        self.title = title
        self.isEnabled = isEnabled
    }
    
    public var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            CancelButton(title, isEnabled: isEnabled)
        }
    }
}
