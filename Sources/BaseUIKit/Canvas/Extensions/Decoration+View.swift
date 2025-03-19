import Foundation
import CoreGraphics

public extension Decoration {
    func render(into context: CGContext, atScale scale: CGFloat) {
        switch self {
        case let .stroke(stroke):
            stroke.render(into: context, atScale: scale)
        case let .fill(fill):
            fill.render(into: context)
        }
    }
    
    func effectiveBounds(for rect: CGRect) -> CGRect {
        switch self {
        case let .stroke(stroke):
            return stroke.effectiveBounds(for: rect)
        case let .fill(fill):
            return fill.effectiveBounds(for: rect)
        }
    }
}

extension Array where Element == Decoration {
    public func effectiveBounds(for rect: CGRect) -> CGRect {
        map { $0.effectiveBounds(for: rect) }
            .reduce(rect) { partial, bounds in
                partial.union(bounds)
            }
    }
}
