import BaseKit
#if canImport(CoreGraphics)
import CoreGraphics

public extension BezierPath {
    func union(_ other: BezierPath, using fillRule: FillRule = .winding) -> BezierPath {
        BezierPath(cgPath.union(other.cgPath, using: fillRule.toCG))
    }

    func subtracting(_ other: BezierPath, using fillRule: FillRule = .winding) -> BezierPath {
        BezierPath(cgPath.subtracting(other.cgPath, using: fillRule.toCG))
    }

    func intersection(_ other: BezierPath, using fillRule: FillRule = .winding) -> BezierPath {
        BezierPath(cgPath.intersection(other.cgPath, using: fillRule.toCG))
    }

    func symmetricDifference(
        _ other: BezierPath, using fillRule: FillRule = .winding
    ) -> BezierPath {
        BezierPath(cgPath.symmetricDifference(other.cgPath, using: fillRule.toCG))
    }
}
#endif
