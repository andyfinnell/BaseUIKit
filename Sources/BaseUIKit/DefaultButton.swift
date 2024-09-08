import SwiftUI

public struct DefaultButton: View {
    @Environment(\.dismiss) private var dismiss
    private let title: String
    private let isEnabled: Bool
    private let action: (DismissAction) -> Void
    
    public init(_ title: String = "OK", isEnabled: Bool = true, action: @escaping (DismissAction) -> Void) {
        self.title = title
        self.isEnabled = isEnabled
        self.action = action
    }
    
    public var body: some View {
        Button(title) {
            action(dismiss)
        }
        .keyboardShortcut(.defaultAction)
        .disabled(!isEnabled)
    }
}

public struct DefaultToolbarItem: ToolbarContent {
    private let title: String
    private let isEnabled: Bool
    private let action: (DismissAction) -> Void

    public init(_ title: String = "OK", isEnabled: Bool = true, action: @escaping (DismissAction) -> Void) {
        self.title = title
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            DefaultButton(title, isEnabled: isEnabled, action: action)
        }
    }
}
