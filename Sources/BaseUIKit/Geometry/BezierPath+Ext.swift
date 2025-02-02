import BaseKit
#if canImport(CoreGraphics)
import CoreGraphics

public extension BezierPath {
    init(_ path: CGPath) {
        var elements = [Element]()
        var previous = CGPoint.zero
        path.applyWithBlock { elementRef in
            switch elementRef.pointee.type {
            case .moveToPoint:
                elements.append(.move(to: Point(elementRef.pointee.points[0])))
                previous = elementRef.pointee.points[0]
            case .addLineToPoint:
                elements.append(.line(to: Point(elementRef.pointee.points[0])))
                previous = elementRef.pointee.points[0]
            case .addQuadCurveToPoint:
                let (controlPoint1, controlPoint2, endPoint) = convertQuadToCubic(from: Point(previous),
                                                                                  controlPoint: Point(elementRef.pointee.points[0]),
                                                                                  to: Point(elementRef.pointee.points[1]))
                elements.append(.curve(to: endPoint,
                                       control1: controlPoint1,
                                       control2: controlPoint2))
                previous = elementRef.pointee.points[1]
            case .addCurveToPoint:
                elements.append(.curve(to: Point(elementRef.pointee.points[2]),
                                       control1: Point(elementRef.pointee.points[0]),
                                       control2: Point(elementRef.pointee.points[1])))
                previous = elementRef.pointee.points[2]
            case .closeSubpath:
                elements.append(.closeSubpath)
            @unknown default:
                break
            }
        }
        self.init(elements: elements)
    }


    var cgPath: CGPath {
        let cgPath = CGMutablePath()
        for element in self {
            switch element {
            case let .move(to: point):
                cgPath.move(to: point.toCG)
            case let .line(to: point):
                cgPath.addLine(to: point.toCG)
            case let .curve(to: point, control1: control1, control2: control2):
                cgPath.addCurve(to: point.toCG,
                                control1: control1.toCG,
                                control2: control2.toCG)
            case .closeSubpath:
                cgPath.closeSubpath()
            }
        }
        return cgPath
    }
}
#endif

func convertQuadToCubic(from currentPoint: Point, controlPoint: Point, to endPoint: Point) -> (controlPoint1: Point, controlPoint2: Point, endPoint: Point) {
    // Create a cubic curve representation of the quadratic curve from
    let ⅔: Real = 2.0 / 3.0
    
    // lastPoint + twoThirds * (via - lastPoint)
    let controlPoint1 = currentPoint + ((controlPoint - currentPoint) * ⅔)
    // toPt + twoThirds * (via - toPt)
    let controlPoint2 = endPoint + ((controlPoint - endPoint) * ⅔)
    
    return (controlPoint1: controlPoint1, controlPoint2: controlPoint2, endPoint: endPoint)
}
