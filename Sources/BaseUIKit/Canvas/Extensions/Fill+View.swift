import Foundation
import CoreGraphics
import BaseKit

public extension Fill {
    func render(into context: CGContext) {
        context.setAlpha(opacity)
        paint.fill(context, using: fillRule.toCG)
    }
    
    func effectiveBounds(for rect: CGRect) -> CGRect {
        rect
    }
}
