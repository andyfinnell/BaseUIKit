import Foundation
import CoreGraphics

public extension Stroke {
    func render(into context: CGContext, atScale scale: CGFloat) {
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
            context.scaleBy(x: 1.0 / scale, y: 1.0 / scale)
        }
        paint.stroke(context)
    }
    
    func effectiveBounds(for rect: CGRect) -> CGRect {
        var width = ceil(width / 2.0)
        var height = ceil(width / 2.0)
        if join == .miter {
            width *= miterLimit
            height *= miterLimit
        }
        return rect.insetBy(dx: -ceil(width), dy: -ceil(height))
    }
}
