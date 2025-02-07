import BaseKit

public enum CanvasQuery: Hashable, Sendable {
    case underLocation(Point)
    case intersectingBounds(Rect)
    case containingBounds(Rect)
    case all
}
