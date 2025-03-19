import BaseKit

public struct Stroke: Hashable, Sendable {
    public let cap: LineCap
    public let join: LineJoin
    public let miterLimit: Double
    public let width: Double
    public let lineDash: LineDash
    public let paint: Paint
    public let opacity: Double
    public let shouldScaleWithZoom: Bool
    
    public init(
        cap: LineCap = .round,
        join: LineJoin = .miter,
        miterLimit: Double = 4.0,
        width: Double = 1,
        lineDash: LineDash = .none,
        paint: Paint,
        opacity: Double = 1.0,
        shouldScaleWithZoom: Bool = true
    ) {
        self.cap = cap
        self.join = join
        self.miterLimit = miterLimit
        self.width = width
        self.lineDash = lineDash
        self.paint = paint
        self.opacity = opacity
        self.shouldScaleWithZoom = shouldScaleWithZoom
    }
}
