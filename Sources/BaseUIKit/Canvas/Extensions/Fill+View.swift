import Foundation
import CoreGraphics
import BaseKit

public extension Fill {
    func render(into context: CGContext, renderingCache: RenderingCache? = nil) {
        context.setAlpha(opacity)
        paint.fill(context, using: fillRule.toCG, renderingCache: renderingCache)
    }

    func effectiveBounds(for rect: CGRect) -> CGRect {
        rect
    }
}
