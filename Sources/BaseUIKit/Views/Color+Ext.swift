import SwiftUI

public extension Color {

    #if os(macOS)
    static let background = Color(NSColor.windowBackgroundColor)
    static let secondaryBackground = Color(NSColor.underPageBackgroundColor)
    static let tertiaryBackground = Color(NSColor.controlBackgroundColor)
    static let systemFill = Color(NSColor.systemFill)
    static let secondarySystemFill = Color(NSColor.secondarySystemFill)
    static let tertiarySystemFill = Color(NSColor.tertiarySystemFill)
    static let quaternarySystemFill = Color(NSColor.quaternarySystemFill)
    static let quinarySystemFill = Color(NSColor.quinarySystemFill)
    static let systemGray = Color(NSColor.systemGray)
    #else
    static let background = Color(UIColor.systemBackground)
    static let secondaryBackground = Color(UIColor.secondarySystemBackground)
    static let tertiaryBackground = Color(UIColor.tertiarySystemBackground)
    static let systemFill = Color(UIColor.systemFill)
    static let secondarySystemFill = Color(UIColor.secondarySystemFill)
    static let tertiarySystemFill = Color(UIColor.tertiarySystemFill)
    static let quaternarySystemFill = Color(UIColor.quaternarySystemFill)
    static let systemGray = Color(UIColor.systemGray)
    #endif
}
