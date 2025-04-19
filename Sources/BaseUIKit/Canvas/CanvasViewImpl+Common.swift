import Foundation
import BaseKit
#if canImport(CoreGraphics)
import CoreGraphics
#endif

extension CanvasViewImpl: CanvasCoreViewDelegate {
    func invalidate(_ invalidations: Set<CanvasInvalidation>) {
        // Phase 1
        var needsToQueueScrollUpdate = false
        for invalidation in invalidations {
            switch invalidation {
            case .invalidateCanvas:
                setNeedsDisplay()
            case let .invalidateRect(rect):
                setNeedsDisplay(rect)
            case .invalidateContentSize:
                invalidateIntrinsicContentSize()
                notifyDimensionsChanged()
                needsToQueueScrollUpdate = true
            case .invalidateCursor:
#if canImport(AppKit)
resetCursor()
#endif
            case .scrollPosition:
                break // skip for phase 1
            }
        }
        
        // Phase 2
        for invalidation in invalidations {
            switch invalidation {
            case .invalidateCanvas,
             .invalidateRect,
             .invalidateContentSize,
             .invalidateCursor:
                break
            case let .scrollPosition(scrollPosition):
                updateScrollPosition(
                    scrollPosition,
                    needsToQueue: needsToQueueScrollUpdate
                )
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

