import BaseKit

public struct MaskLayer: Hashable, Sendable {
    public typealias MaskShape = DecoratedShape

    public let bounds: Rect
    public let shapes: [DecoratedShape]

    public init(bounds: Rect, shapes: [DecoratedShape]) {
        self.bounds = bounds
        self.shapes = shapes
    }
}
