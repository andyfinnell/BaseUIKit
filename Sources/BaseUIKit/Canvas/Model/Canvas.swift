import BaseKit

public struct Canvas<ID: Hashable & Sendable>: Hashable, Sendable {
    public let width: Double
    public let height: Double
    public let contentTransform: Transform
    public let backgroundColor: Color?
    public let layers: [Layer<ID>]
    
    public init(
        width: Double,
        height: Double,
        contentTransform: Transform,
        backgroundColor: Color?,
        layers: [Layer<ID>]
    ) {
        self.width = width
        self.height = height
        self.contentTransform = contentTransform
        self.backgroundColor = backgroundColor
        self.layers = layers
    }
    
    public func overlay(_ layers: [Layer<ID>]) -> Canvas<ID> {
        Canvas(
            width: width,
            height: height,
            contentTransform: contentTransform,
            backgroundColor: backgroundColor,
            layers: self.layers + layers
        )
    }
}

public extension Canvas {
    static func empty() -> Canvas {
        Canvas(width: 100, height: 100, contentTransform: .identity, backgroundColor: nil, layers: [])
    }
}
