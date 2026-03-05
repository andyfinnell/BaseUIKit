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

        // Always draw at pixel dimensions in the callback (no capture needed).
        // Use bounds/step/matrix to control tiling size and position.
        let pixelW = CGFloat(image.width)
        let pixelH = CGFloat(image.height)

        // Compute the effective tile size in user space
        let effectiveW: CGFloat
        let effectiveH: CGFloat
        if tileWidth > 0, tileHeight > 0 {
            if let boundingBox {
                effectiveW = CGFloat(tileWidth) * CGFloat(boundingBox.width)
                effectiveH = CGFloat(tileHeight) * CGFloat(boundingBox.height)
            } else {
                effectiveW = CGFloat(tileWidth)
                effectiveH = CGFloat(tileHeight)
            }
        } else {
            effectiveW = pixelW
            effectiveH = pixelH
        }

        // Build pattern matrix:
        // 1. Scale from pixel space to effective tile space
        // 2. Apply bounding box offset (if objectBoundingBox)
        // 3. Apply patternTransform
        var matrix = CGAffineTransform.identity

        // Scale from pixel space to tile space
        if effectiveW != pixelW || effectiveH != pixelH {
            matrix = matrix.scaledBy(x: effectiveW / pixelW, y: effectiveH / pixelH)
        }

        if let boundingBox {
            matrix = matrix.concatenating(
                CGAffineTransform(translationX: CGFloat(boundingBox.x), y: CGFloat(boundingBox.y))
            )
        }

        if let patternTransform {
            matrix = matrix.concatenating(patternTransform.toCG)
        }

        func drawPattern(info: UnsafeMutableRawPointer?, context: CGContext) {
            guard let info else {
                return
            }
            let image: CGImage = Unmanaged.fromOpaque(info).takeUnretainedValue()
            context.draw(image,
                         in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }

        func releaseInfo(info: UnsafeMutableRawPointer?) {
            guard let info else {
                return
            }
            Unmanaged<CGImage>.fromOpaque(info).release()
        }

        var callbacks = CGPatternCallbacks(version: 0,
                                           drawPattern: drawPattern,
                                           releaseInfo: releaseInfo)

        let info: UnsafeMutableRawPointer = Unmanaged.passRetained(image).toOpaque()
        return CGPattern(info: info,
                         bounds: CGRect(x: 0, y: 0, width: pixelW, height: pixelH),
                         matrix: matrix,
                         xStep: pixelW,
                         yStep: pixelH,
                         tiling: .noDistortion,
                         isColored: true,
                         callbacks: &callbacks)
    }
}
