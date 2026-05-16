import Foundation
import CoreGraphics
import BaseKit

public extension Decoration {
    func render(into context: CGContext, atScale scale: CGFloat, renderingCache: RenderingCache? = nil) {
        switch self {
        case let .stroke(stroke):
            stroke.render(into: context, atScale: scale, renderingCache: renderingCache)
        case let .fill(fill):
            fill.render(into: context, renderingCache: renderingCache)
        }
    }

    func effectiveBounds(for rect: CGRect, atScale scale: CGFloat) -> CGRect {
        switch self {
        case let .stroke(stroke):
            return stroke.effectiveBounds(for: rect, atScale: scale)
        case let .fill(fill):
            return fill.effectiveBounds(for: rect)
        }
    }
}

extension Array where Element == Decoration {
    public func effectiveBounds(for rect: CGRect, atScale scale: CGFloat) -> CGRect {
        map { $0.effectiveBounds(for: rect, atScale: scale) }
            .reduce(rect) { partial, bounds in
                partial.union(bounds)
            }
    }
}
