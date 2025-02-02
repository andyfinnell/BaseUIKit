import Foundation
import CoreGraphics
import BaseKit

public extension Transform {
    var toCG: CGAffineTransform {
        CGAffineTransform(
            a: a,
            b: b,
            c: c,
            d: d,
            tx: translateX,
            ty: translateY
        )
    }
    
    func apply(to rect: CGRect) -> CGRect {
        rect.applying(toCG)
    }
}

public extension AnchorPoint {
    func offset(of rect: CGRect) -> CGPoint {
        switch self {
        case .topLeft:
            return .zero
        case .topCenter:
            return CGPoint(x: rect.width / 2.0, y: 0)
        case .topRight:
            return CGPoint(x: rect.width, y: 0)
        case .centerLeft:
            return CGPoint(x: 0, y: rect.height / 2.0)
        case .center:
            return CGPoint(x: rect.width / 2.0, y: rect.height / 2.0)
        case .centerRight:
            return CGPoint(x: rect.width, y: rect.height / 2.0)
        case .bottomLeft:
            return CGPoint(x: 0, y: rect.height)
        case .bottomCenter:
            return CGPoint(x: rect.width / 2.0, y: rect.height)
        case .bottomRight:
            return CGPoint(x: rect.width, y: rect.height)
        }
    }
}
