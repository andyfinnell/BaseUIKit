import BaseKit

public struct Fill: Hashable, Sendable {
    public let paint: Paint
    public let opacity: Double
    public let fillRule: FillRule
    
    public init(paint: Paint, opacity: Double = 1.0, fillRule: FillRule = .evenOdd) {
        self.paint = paint
        self.opacity = opacity
        self.fillRule = fillRule
    }
}
