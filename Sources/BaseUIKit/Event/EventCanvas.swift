import BaseKit

public struct EventCanvas: Hashable, Sendable {
    public let dimensions: CanvasViewDimensions
    public let zoom: Double
    public let scrollPosition: Point
    public let visibleRect: Rect
    public let areWindowCoordsFlipped: Bool
    
    public init(
        dimensions: CanvasViewDimensions,
        zoom: Double,
        scrollPosition: Point,
        visibleRect: Rect,
        areWindowCoordsFlipped: Bool
    ) {
        self.dimensions = dimensions
        self.zoom = zoom
        self.scrollPosition = scrollPosition
        self.visibleRect = visibleRect
        self.areWindowCoordsFlipped = areWindowCoordsFlipped
    }
}
