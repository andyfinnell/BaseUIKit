import Foundation
import CoreGraphics
import BaseKit

public extension Paint {
    func fill(_ context: CGContext, using fillRule: CGPathFillRule) {
        switch self {
        case let .solid(solid):
            solid.fill(context, using: fillRule)
        case let .gradient(gradient):
            gradient.fill(context, using: fillRule)
        case let .pattern(pattern):
            pattern.fill(context, using: fillRule)
        }
    }
    
    func stroke(_ context: CGContext) {
        switch self {
        case let .solid(solid):
            solid.stroke(context)
        case let .gradient(gradient):
            gradient.stroke(context)
        case let .pattern(pattern):
            pattern.stroke(context)
        }
    }
}
