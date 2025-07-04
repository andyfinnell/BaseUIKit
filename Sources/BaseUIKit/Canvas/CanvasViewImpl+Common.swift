import Foundation
import BaseKit
#if canImport(CoreGraphics)
import CoreGraphics
#endif

extension CanvasViewImpl: CanvasCoreViewDelegate {
    func invalidate(_ invalidations: Set<CanvasInvalidation>) {
        // Phase 1
        for invalidation in invalidations {
            switch invalidation {
            case .invalidateCanvas:
                setNeedsDisplay()
            case let .invalidateRect(rect):
                setNeedsDisplay(rect)
            case .invalidateContentSize:
                invalidateIntrinsicContentSize()
                updateContentInsets()
                notifyDimensionsChanged()
            case let .invalidateViewScale(viewScale):
                #if os(iOS)
                updateViewScale(viewScale)
                #endif
                
            case .invalidateCursor:
#if canImport(AppKit)
resetCursor()
#endif
            case .scrollPosition,
                    .scrollPositionCenteredAt:
                break // skip for phase 1
            }
        }
        
        // Phase 2
        for invalidation in invalidations {
            switch invalidation {
            case .invalidateCanvas,
             .invalidateRect,
             .invalidateContentSize,
             .invalidateViewScale,
             .invalidateCursor:
                break
            case let .scrollPosition(scrollPosition):
                updateScrollPosition(scrollPosition)
            case let .scrollPositionCenteredAt(scrollPosition):
                updateScrollPosition(centeredAt: scrollPosition)
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

