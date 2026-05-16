import Foundation
import CoreGraphics
import BaseKit

public extension Stroke {
    func render(into context: CGContext, atScale scale: CGFloat, renderingCache: RenderingCache? = nil) {
        context.setLineWidth(width)
        context.setLineJoin(join.toCG)
        context.setLineCap(cap.toCG)
        context.setMiterLimit(miterLimit)
        if lineDash.isSet {
            context.setLineDash(phase: lineDash.phase,
                                lengths: lineDash.lengths.map { CGFloat($0) })
        }
        context.setAlpha(opacity)
        if !shouldScaleWithZoom {
            context.saveGState()
            context.scaleBy(x: 1.0 / scale, y: 1.0 / scale)
        }
        paint.stroke(context, renderingCache: renderingCache)
        if !shouldScaleWithZoom {
            context.restoreGState()
        }
    }

    /// Same as `effectiveBounds(for:)` but accounts for
    /// `shouldScaleWithZoom: false`: the stroke is rendered at
    /// `width / scale` doc-pt, so the bounds inset shrinks accordingly.
    func effectiveBounds(for rect: CGRect, atScale scale: CGFloat) -> CGRect {
        var width = ceil(ceil(self.width) / 2.0)
        if join == .miter {
            width *= miterLimit
        }
        if !shouldScaleWithZoom {
            width = ceil(width / max(scale, 0.0001))
        }
        return rect.insetBy(dx: -ceil(width), dy: -ceil(width))
    }
}
