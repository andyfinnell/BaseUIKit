import BaseKit

#if canImport(UIKit)
import UIKit

extension UIBezierPath: @retroactive BezierPathRenderable {
    public var fillRule: BaseKit.FillRule {
        get {
            usesEvenOddFillRule ? .evenOdd : .winding
        }
        set {
            usesEvenOddFillRule = switch newValue {
            case .evenOdd: true
            case .winding: false
            }
        }
    }
    
    public var strokeLineWidth: BaseKit.Real {
        get {
            lineWidth
        }
        set {
            lineWidth = newValue
        }
    }
    
    public var strokeLineCap: BaseKit.LineCap {
        get {
            switch lineCapStyle {
            case .butt: .butt
            case .round: .round
            case .square: .square
            @unknown default: .round
            }
        }
        set {
            lineCapStyle = switch newValue {
            case .butt: .butt
            case .round: .round
            case .square: .square
            }
        }
    }
    
    public var strokeLineJoin: BaseKit.LineJoin {
        get {
            switch lineJoinStyle {
            case .bevel: .bevel
            case .round: .round
            case .miter: .miter
            @unknown default: .miter
            }
        }
        set {
            lineJoinStyle = switch newValue {
            case .bevel: .bevel
            case .round: .round
            case .miter: .miter
            }
        }
    }
    
    public var strokeMiterLimit: BaseKit.Real {
        get {
            miterLimit
        }
        set {
            miterLimit = newValue
        }
    }
    
    public var strokeFlatness: BaseKit.Real {
        get {
            flatness
        }
        set {
            flatness = newValue
        }
    }
        
    public func move(to point: Point) {
        move(to: point.toCG)
    }
    
    public func addCurve(to point: Point, controlPoint1: Point, controlPoint2: Point) {
        addCurve(to: point.toCG,
                 controlPoint1: controlPoint1.toCG,
                 controlPoint2: controlPoint2.toCG)
    }
    
    public func addLine(to point: Point) {
        addLine(to: point.toCG)
    }
    
    public func setStrokeLineDash(_ pattern: [BaseKit.Real], phase: BaseKit.Real) {
        var patternArray = pattern.map { CGFloat($0) }
        if pattern.isEmpty {
            setLineDash(nil, count: 0, phase: phase)
        } else {
            setLineDash(&patternArray, count: pattern.count, phase: phase)
        }
    }
    
    public func closeSubpath() {
        close()
    }
    
    public func enumerate(_ block: (BezierPath.Element) -> Void) {
        var previous = CGPoint.zero
        cgPath.applyWithBlock { elementRef in
            switch elementRef.pointee.type {
            case .moveToPoint:
                block(.move(to: Point(elementRef.pointee.points[0])))
                previous = elementRef.pointee.points[0]
            case .addLineToPoint:
                block(.line(to: Point(elementRef.pointee.points[0])))
                previous = elementRef.pointee.points[0]
            case .addQuadCurveToPoint:
                let (controlPoint1, controlPoint2, endPoint) = convertQuadToCubic(from: Point(previous),
                                                                                  controlPoint: Point(elementRef.pointee.points[0]),
                                                                                  to: Point(elementRef.pointee.points[1]))
                block(.curve(to: endPoint,
                             control1: controlPoint1,
                             control2: controlPoint2))
                previous = elementRef.pointee.points[1]

            case .addCurveToPoint:
                block(.curve(to: Point(elementRef.pointee.points[2]),
                             control1: Point(elementRef.pointee.points[0]),
                             control2: Point(elementRef.pointee.points[1])))
                previous = elementRef.pointee.points[2]
            case .closeSubpath:
                block(.closeSubpath)
            @unknown default:
                break
            }
        }
    }
    
    public func transform(_ transform: Transform) {
        let affineTransform = CGAffineTransform(
            a: transform.a,
            b: transform.b,
            c: transform.c,
            d: transform.d,
            tx: transform.translateX,
            ty: transform.translateY
        )
        return apply(affineTransform)
    }
}
#endif

#if canImport(AppKit)
import AppKit

extension NSBezierPath: @retroactive BezierPathRenderable {
    public var fillRule: BaseKit.FillRule {
        get {
            switch windingRule {
            case .evenOdd:
                BaseKit.FillRule.evenOdd
            case .nonZero:
                BaseKit.FillRule.winding
            @unknown default:
                BaseKit.FillRule.winding
            }
        }
        set {
            windingRule = switch newValue {
            case .evenOdd: .evenOdd
            case .winding: .nonZero
            }
        }
    }
    
    public var strokeLineWidth: BaseKit.Real {
        get {
            lineWidth
        }
        set {
            lineWidth = newValue
        }
    }
    
    public var strokeLineCap: BaseKit.LineCap {
        get {
            switch lineCapStyle {
            case .butt: .butt
            case .round: .round
            case .square: .square
            @unknown default: .round
            }
        }
        set {
            lineCapStyle = switch newValue {
            case .butt: .butt
            case .round: .round
            case .square: .square
            }
        }
    }
    
    public var strokeLineJoin: BaseKit.LineJoin {
        get {
            switch lineJoinStyle {
            case .bevel: .bevel
            case .miter: .miter
            case .round: .round
            @unknown default: .miter
            }
        }
        set {
            lineJoinStyle = switch newValue {
            case .bevel: .bevel
            case .miter: .miter
            case .round: .round
            }
        }
    }
    
    public var strokeMiterLimit: BaseKit.Real {
        get {
            miterLimit
        }
        set {
            miterLimit = newValue
        }
    }
    
    public var strokeFlatness: BaseKit.Real {
        get {
            flatness
        }
        set {
            flatness = newValue
        }
    }
        
    public func move(to point: Point) {
        move(to: point.toCG)
    }

    public func addCurve(to point: Point, controlPoint1: Point, controlPoint2: Point) {
        curve(to: point.toCG,
              controlPoint1: controlPoint1.toCG,
              controlPoint2: controlPoint2.toCG)
    }
    
    public func addLine(to point: Point) {
        line(to: point.toCG)
    }
        
    public func setStrokeLineDash(_ pattern: [Real], phase: Real) {
        var patternArray = pattern.map { CGFloat($0) }
        if pattern.isEmpty {
            setLineDash(nil, count: 0, phase: phase)
        } else {
            setLineDash(&patternArray, count: pattern.count, phase: phase)
        }
    }
    
    public func closeSubpath() {
        close()
    }
    
    public func enumerate(_ block: (BezierPath.Element) -> Void) {
        var points = Array(repeating: CGPoint.zero, count: 3)
        var previous = CGPoint.zero
        for i in 0..<elementCount {
            let kind = element(at: i, associatedPoints: &points)
            switch kind {
            case .moveTo:
                block(.move(to: Point(points[0])))
                previous = points[0]
            case .lineTo:
                block(.line(to: Point(points[0])))
                previous = points[0]
            case .curveTo, .cubicCurveTo:
                block(.curve(to: Point(points[2]),
                             control1: Point(points[0]),
                             control2: Point(points[1])))
                previous = points[2]
            case .closePath:
                block(.closeSubpath)
            case .quadraticCurveTo:
                let (controlPoint1, controlPoint2, endPoint) = convertQuadToCubic(from: Point(previous),
                                                                                  controlPoint: Point(points[0]),
                                                                                  to: Point(points[1]))
                block(.curve(to: endPoint,
                             control1: controlPoint1,
                             control2: controlPoint2))
                previous = points[1]

            @unknown default:
                break
            }
        }
    }
    
    public func transform(_ transform: Transform) {
        let affineTransform = AffineTransform(m11: transform.a,
                                              m12: transform.b,
                                              m21: transform.c,
                                              m22: transform.d,
                                              tX: transform.translateX,
                                              tY: transform.translateY)
        self.transform(using: affineTransform)
    }
    
}
#endif
