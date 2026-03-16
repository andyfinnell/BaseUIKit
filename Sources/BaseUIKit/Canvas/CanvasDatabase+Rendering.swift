import Foundation
import CoreGraphics
import BaseKit

public extension CanvasDatabase {
    func renderToImage(width: Int, height: Int) -> CGImage? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            return nil
        }
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        // Flip to top-left origin to match the flipped NSView/UIView coordinate
        // system that drawRect expects
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        setBounds(rect)
        drawRect(rect, into: context)
        return context.makeImage()
    }

    /// Renders only the specified layers to an image, sized to their bounding box.
    func renderElementsToImage(ids: Set<ID>, scale: CGFloat = 2) -> CGImage? {
        let bounds = effectBounds(ofIDs: Array(ids))
        guard bounds.width > 0, bounds.height > 0 else { return nil }

        let cgBounds = bounds.toCG
        let width = Int(ceil(cgBounds.width * scale))
        let height = Int(ceil(cgBounds.height * scale))
        guard width > 0, height > 0 else { return nil }

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Flip to top-left origin
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        // Scale for retina
        context.scaleBy(x: scale, y: scale)

        // Translate so the bounding box origin maps to (0, 0)
        context.translateBy(x: -cgBounds.minX, y: -cgBounds.minY)

        drawElements(ids: ids, in: cgBounds, into: context, atScale: scale)
        return context.makeImage()
    }

    /// Renders only the specified layers to PDF data, sized to their bounding box.
    func renderElementsToPDFData(ids: Set<ID>) -> Data? {
        let bounds = effectBounds(ofIDs: Array(ids))
        guard bounds.width > 0, bounds.height > 0 else { return nil }

        let cgBounds = bounds.toCG
        var mediaRect = CGRect(x: 0, y: 0, width: cgBounds.width, height: cgBounds.height)
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return nil }
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaRect, nil) else { return nil }

        context.beginPDFPage(nil)

        // PDF has bottom-left origin; flip to top-left to match drawing system
        context.translateBy(x: 0, y: mediaRect.height)
        context.scaleBy(x: 1, y: -1)

        // Translate so the bounding box origin maps to (0, 0)
        context.translateBy(x: -cgBounds.minX, y: -cgBounds.minY)

        drawElements(ids: ids, in: cgBounds, into: context, atScale: 1)

        context.endPDFPage()
        context.closePDF()
        return data as Data
    }
}
