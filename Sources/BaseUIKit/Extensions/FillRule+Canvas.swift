import BaseKit
import CoreGraphics

public extension FillRule {
    var toCG: CGPathFillRule {
        switch self {
        case .evenOdd: .evenOdd
        case .winding: .winding
        }
    }
}
