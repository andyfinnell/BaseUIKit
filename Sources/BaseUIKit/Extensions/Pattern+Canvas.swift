import Foundation
import CoreGraphics
import ImageIO
import BaseKit

public extension Pattern {
    func fill(_ context: CGContext, using fillRule: CGPathFillRule) {
        guard let pattern,
              let colorSpace = CGColorSpace(patternBaseSpace: nil) else {
            return
        }
        
        context.saveGState()
        
        context.setFillColorSpace(colorSpace)
        var components: [CGFloat] = [1.0, 1.0, 1.0, 1.0]
        context.setFillPattern(pattern, colorComponents: &components)
        context.fillPath(using: fillRule)

        context.restoreGState()
    }
    
    func stroke(_ context: CGContext) {
        guard let pattern,
              let colorSpace = CGColorSpace(patternBaseSpace: nil) else {
            return
        }
        
        context.saveGState()
        
        context.setStrokeColorSpace(colorSpace)
        var components: [CGFloat] = [1.0, 1.0, 1.0, 1.0]
        context.setStrokePattern(pattern, colorComponents: &components)
        context.strokePath()
        
        context.restoreGState()
    }
}

private extension Pattern {
    var image: CGImage? {
        // TODO: cache?
        guard let source = CGImageSourceCreateWithData(imageData as CFData,
                                                       [kCGImageSourceShouldCache: true] as CFDictionary) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
    
    var pattern: CGPattern? {
        guard let image else {
            return nil
        }
        
        let xStep = CGFloat(image.width)
        let yStep = CGFloat(image.height)
        
        func drawPattern(info: UnsafeMutableRawPointer?, context: CGContext) {
            guard let info else {
                return
            }
            let image: CGImage = Unmanaged.fromOpaque(info).takeUnretainedValue()
            context.draw(image,
                         in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

        }
        
        var callbacks = CGPatternCallbacks(version: 0,
                                           drawPattern: drawPattern,
                                           releaseInfo: nil)

        let info: UnsafeMutableRawPointer = Unmanaged.passUnretained(image).toOpaque()
        return CGPattern(info: info,
                         bounds: CGRect(x: 0, y: 0, width: image.width, height: image.height),
                         matrix: .identity,
                         xStep: xStep,
                         yStep: yStep,
                         tiling: .noDistortion,
                         isColored: true,
                         callbacks: &callbacks)
    }
}
