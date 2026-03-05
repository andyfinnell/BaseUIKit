import CoreGraphics
import BaseKit

extension DecoratedShape {
    func render(into context: CGContext, atScale scale: CGFloat) {
        context.saveGState()
        context.setAlpha(CGFloat(opacity))
        context.concatenate(transform.toCG)
        for decoration in decorations {
            path.set(in: context)
            decoration.render(into: context, atScale: scale)
        }
        context.restoreGState()
    }
}

extension Array where Element == DecoratedShape {
    func renderToImage(
        width: Int,
        height: Int,
        contentTransform: CGAffineTransform = .identity
    ) -> CGImage? {
        guard width > 0, height > 0 else { return nil }
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        guard let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.concatenate(contentTransform)

        for shape in self {
            shape.render(into: context, atScale: 1.0)
        }
        return context.makeImage()
    }
}
