import CoreGraphics

enum CanvasInvalidation: Hashable, Sendable {
    case invalidateCanvas
    case invalidateRect(CGRect)
    case invalidateContentSize
    case invalidateCursor
    
    /// macOS views aren't layer backed, and changing their transform just does
    /// a redraw, which is what CanvasDatabase does by default anyway. So it's
    /// not an optimization like it is on iOS.
    @available(macOS, unavailable)
    case invalidateViewScale(CGFloat)
    
    case scrollPosition(CGPoint)
    case scrollPositionCenteredAt(CGPoint)
}
