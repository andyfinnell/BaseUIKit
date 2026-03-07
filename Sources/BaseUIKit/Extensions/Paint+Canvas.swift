import Foundation
import CoreGraphics
import BaseKit

public extension Paint {
    func fill(_ context: CGContext, using fillRule: CGPathFillRule, renderingCache: RenderingCache? = nil) {
        switch self {
        case let .solid(solid):
            solid.fill(context, using: fillRule)
        case let .gradient(gradient):
            gradient.fill(context, using: fillRule)
        case let .pattern(pattern):
            pattern.fill(context, using: fillRule, renderingCache: renderingCache)
        }
    }

    func stroke(_ context: CGContext, renderingCache: RenderingCache? = nil) {
        switch self {
        case let .solid(solid):
            solid.stroke(context)
        case let .gradient(gradient):
            gradient.stroke(context)
        case let .pattern(pattern):
            pattern.stroke(context, renderingCache: renderingCache)
        }
    }
}
