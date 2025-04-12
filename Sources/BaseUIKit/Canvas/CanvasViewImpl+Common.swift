import Foundation
import BaseKit
#if canImport(CoreGraphics)
import CoreGraphics
#endif

extension CanvasViewImpl: CanvasCoreViewDelegate {
    func invalidate(_ invalidations: Set<CanvasInvalidation>) {
        for invalidation in invalidations {
            switch invalidation {
            case .invalidateCanvas:
                setNeedsDisplay()
            case let .invalidateRect(rect):
                setNeedsDisplay(rect)
            case .invalidateContentSize:
                invalidateIntrinsicContentSize()
                notifyDimensionsChanged()
            case .invalidateCursor:
#if canImport(AppKit)
resetCursor()
#endif
            }
        }
    }
}

extension CanvasViewImpl {
    func notifyDimensionsChanged() {
        guard let onDimensionsChanged else {
            return
        }
        let dimensions = db.dimensions
        onDimensionsChanged(dimensions)
    }
    
    func sendEvent(_ event: Event) {
        onEvent?(event)
    }
}

