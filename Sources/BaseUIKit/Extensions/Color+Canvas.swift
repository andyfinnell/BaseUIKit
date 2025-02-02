import Foundation
import CoreGraphics
import BaseKit

public extension Color {
    var toCG: CGColor {
        CGColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    func setStroke(in context: CGContext) {
        context.setStrokeColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    func setFill(in context: CGContext) {
        context.setFillColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    func fill(_ context: CGContext, using fillRule: CGPathFillRule) {
        context.saveGState()
        setFill(in: context)
        context.fillPath(using: fillRule)
        context.restoreGState()
    }
    
    func stroke(_ context: CGContext) {
        context.saveGState()
        setStroke(in: context)
        context.strokePath()
        context.restoreGState()
    }
}

#if canImport(AppKit)
import AppKit

public typealias NativeColor = NSColor

public extension Color {
    var toNative: NativeColor {
        NativeColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}
#endif

#if canImport(UIKit)
import UIKit

public typealias NativeColor = UIColor

public extension Color {
    var toNative: NativeColor {
        NativeColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}
#endif
