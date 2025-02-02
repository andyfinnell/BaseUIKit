import BaseKit

#if canImport(CoreGraphics)
import CoreGraphics

public extension Size {
    init(_ size: CGSize) {
        self.init(width: size.width, height: size.height)
    }
    
    var toCG: CGSize {
        .init(width: width, height: height)
    }
}

#endif

