import Foundation
import CoreGraphics
import BaseKit

public extension Color {
    init(cgColor: CGColor) {
        let sRGB = CGColorSpace(name: CGColorSpace.sRGB)
        if let sRGB, cgColor.colorSpace != sRGB {
            if let newColor = cgColor.converted(to: sRGB, intent: .defaultIntent, options: nil) {
                self.init(assumeSRGB: newColor)
            } else {
                self.init(red: 0, green: 0, blue: 0, alpha: 1)
            }
        } else {
            self.init(assumeSRGB: cgColor)
        }
    }
    
    private init(assumeSRGB: CGColor) {
        if let components = assumeSRGB.components, components.count >= 3 {
            if components.count > 3 {
                self.init(red: components[0], green: components[1], blue: components[2], alpha: components[3])
            } else {
                self.init(red: components[0], green: components[1], blue: components[2], alpha: 1.0)
            }
        } else {
            self.init(red: 0, green: 0, blue: 0, alpha: 1)
        }
    }
    
    var toCG: CGColor {
        CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
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
