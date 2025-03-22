import Foundation
import BaseKit
#if canImport(CoreGraphics)
import CoreGraphics
#endif

extension CanvasViewImpl: CanvasCoreViewDelegate {
    func invalidateCanvas() {
        setNeedsDisplay()
    }
    
    func invalidateRect(_ rect: CGRect) {
        setNeedsDisplay(rect)
    }
    
    func invalidateContentSize() {
        invalidateIntrinsicContentSize()
        notifyDimensionsChanged()
    }
    
    func invalidateCursor() {
        #if canImport(AppKit)
        resetCursor()
        #endif
    }
}

extension CanvasViewImpl {
    func notifyDimensionsChanged() {
        guard let onDimensionsChanged else {
            return
        }
        let dimensions = CanvasViewDimensions(
            size: Size(width: database.width, height: database.height),
            screenDPI: database.screenDPI
        )
        onDimensionsChanged(dimensions)
    }
    
    func sendEvent(_ event: Event) {
        onEvent?(event)
    }
}

