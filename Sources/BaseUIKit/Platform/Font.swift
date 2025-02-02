import Foundation

#if canImport(AppKit)
import AppKit

public typealias NativeFont = NSFont

#endif

#if canImport(UIKit)
import UIKit

public typealias NativeFont = UIFont

#endif

public struct Font {
    public let native: NativeFont
    
    public init(name: String, size: Double) {
        native = NativeFont(name: name, size: size) ?? NativeFont.systemFont(ofSize: size)
    }
}
