import BaseKit

public struct ClipPath: Hashable, Sendable {
    public let path: BezierPath
    public let fillRule: FillRule

    public init(path: BezierPath, fillRule: FillRule = .winding) {
        self.path = path
        self.fillRule = fillRule
    }
}
