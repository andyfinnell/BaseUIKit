import Foundation
import CoreGraphics
import BaseKit

public extension Gradient {
    func fill(_ context: CGContext, using fillRule: CGPathFillRule) {
        guard let gradient else {
            return
        }

        context.saveGState()
        context.beginTransparencyLayer(auxiliaryInfo: nil)

        context.clip(using: fillRule)

        if let boundingBox {
            context.translateBy(x: boundingBox.minX, y: boundingBox.minY)
            context.scaleBy(x: boundingBox.width, y: boundingBox.height)
        }

        if let gradientTransform {
            context.concatenate(gradientTransform.toCG)
        }

        let drawingOptions = spreadDrawingOptions

        switch kind {
        case .linear:
            context.drawLinearGradient(gradient,
                                       start: start.toCG,
                                       end: end.toCG,
                                       options: drawingOptions)

        case .radial:
            let startCenter = (focalPoint ?? start).toCG
            context.drawRadialGradient(gradient,
                                       startCenter: startCenter,
                                       startRadius: 0,
                                       endCenter: start.toCG,
                                       endRadius: start.distance(to: end),
                                       options: drawingOptions)
        }
        context.endTransparencyLayer()
        context.restoreGState()
    }
    
    func stroke(_ context: CGContext) {
        context.saveGState()

        context.replacePathWithStrokedPath()
        fill(context, using: .evenOdd)
        
        context.restoreGState()
    }
}

private extension Gradient {
    var gradient: CGGradient? {
        // TODO: maybe cache this?
        let colors = stops.map { $0.color.toCG }
        var locations = stops.map { CGFloat($0.offset) }
        return CGGradient(colorsSpace: nil, colors: colors as CFArray, locations: &locations)
    }

    var spreadDrawingOptions: CGGradientDrawingOptions {
        switch spreadMethod {
        case .pad:
            [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        case .reflect, .repeat:
            []
        }
    }
}
