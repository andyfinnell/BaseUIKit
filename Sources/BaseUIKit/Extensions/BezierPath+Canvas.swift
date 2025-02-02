import Foundation
import CoreGraphics
import BaseKit

public extension BezierPath {
    func `set`(in context: CGContext) {
        context.beginPath()
        add(in: context)
    }
    
    func add(in context: CGContext) {
        for element in elements {
            element.add(in: context)
        }
    }
    
    var cgQuickBounds: CGRect {
        quickBounds?.toCG ?? .null
    }
}

public extension BezierPath.Element {
    func add(in context: CGContext) {
        switch self {
        case let .move(to: point):
            context.move(to: point.toCG)
        case let .line(to: point):
            context.addLine(to: point.toCG)
        case let .curve(to: point, control1: control1, control2: control2):
            context.addCurve(to: point.toCG,
                             control1: control1.toCG,
                             control2: control2.toCG)
        case .closeSubpath:
            context.closePath()
        }
    }
}
