import CoreGraphics

enum CanvasInvalidation: Hashable, Sendable {
    case invalidateCanvas
    case invalidateRect(CGRect)
    case invalidateContentSize
    case invalidateCursor
}
