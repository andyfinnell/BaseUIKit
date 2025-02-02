import BaseKit

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

public extension TextAlignment {
    init(native: NSTextAlignment) {
        switch native {
        case .left:
            self = .leading
        case .right:
            self = .trailing
        case .center:
            self = .center
        case .justified:
            self = .justified
        case .natural:
            self = .default
        @unknown default:
            self = .default
        }
    }
    
    var toNative: NSTextAlignment {
        switch self {
        case .default:
            return .natural
        case .leading:
            return .left
        case .trailing:
            return .right
        case .center:
            return .center
        case .justified:
            return .justified
        }
    }
}
