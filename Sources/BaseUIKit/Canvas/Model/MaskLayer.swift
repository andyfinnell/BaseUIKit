import BaseKit

public struct MaskLayer: Hashable, Sendable {
    public struct MaskShape: Hashable, Sendable {
        public let path: BezierPath
        public let transform: Transform
        public let decorations: [Decoration]
        public let opacity: Double

        public init(
            path: BezierPath,
            transform: Transform = .identity,
            decorations: [Decoration] = [],
            opacity: Double = 1.0
        ) {
            self.path = path
            self.transform = transform
            self.decorations = decorations
            self.opacity = opacity
        }
    }

    public let bounds: Rect
    public let shapes: [MaskShape]

    public init(bounds: Rect, shapes: [MaskShape]) {
        self.bounds = bounds
        self.shapes = shapes
    }
}
