import BaseKit

#if canImport(CoreGraphics)
import CoreGraphics

public extension Rect {
    init(_ rect: CGRect) {
        self.init(origin: Point(rect.origin), size: Size(rect.size))
    }
    
    var toCG: CGRect {
        .init(origin: origin.toCG, size: size.toCG)
    }
}

#endif

