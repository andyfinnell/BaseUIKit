import BaseKit
#if canImport(CoreGraphics)
import CoreGraphics

public extension BezierPath {
    /// Returns a new path that traces the outline of this path's stroke.
    /// The result, when filled, draws the same shape as stroking the original.
    func stroked(
        width: Double,
        lineCap: LineCap,
        lineJoin: LineJoin,
        miterLimit: Double,
        dash: LineDash = .none
    ) -> BezierPath {
        var result = cgPath

        if dash.isSet {
            let cgLengths = dash.lengths.map { CGFloat($0) }
            result = result.copy(
                dashingWithPhase: CGFloat(dash.phase),
                lengths: cgLengths
            )
        }

        result = result.copy(
            strokingWithWidth: width,
            lineCap: lineCap.toCG,
            lineJoin: lineJoin.toCG,
            miterLimit: miterLimit
        )

        return BezierPath(result)
    }
}
#endif
