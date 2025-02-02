import BaseKit
import SwiftUI

public extension BaseKit.Color {
    var swiftUI: SwiftUI.Color {
        SwiftUI.Color(
            red: red,
            green: green,
            blue: blue,
            opacity: alpha
        )
    }
}

#if canImport(AppKit)
import AppKit

public extension BaseKit.Color {
    init(native: NSColor) {
        let sourceColor = native.usingColorSpace(NSColorSpace.sRGB) ?? native
        self.init(
            red: sourceColor.redComponent,
            green: sourceColor.greenComponent,
            blue: sourceColor.blueComponent,
            alpha: sourceColor.alphaComponent
        )
    }
    
    var native: NSColor {
        NSColor(
            srgbRed: red,
            green: green,
            blue: blue,
            alpha: alpha
        )
    }
}
#endif

#if canImport(UIKit)
import UIKit

public extension BaseKit.Color {
    init(native: UIColor) {
        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0
        var alpha: CGFloat = 0.0
        native.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.init(
            red: red,
            green: green,
            blue: blue,
            alpha: alpha
        )
    }
    
    var native: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}
#endif
