import SwiftUI

public extension SwiftUI.Color {
    static func random() -> SwiftUI.Color {
        SwiftUI.Color(
            hue: Double.random(in: 0...1),
            saturation: Double.random(in: 0...1),
            brightness: Double.random(in: 0...1)
        )
    }
}
