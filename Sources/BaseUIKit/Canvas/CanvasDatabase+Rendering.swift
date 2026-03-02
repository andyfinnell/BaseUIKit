import CoreGraphics

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
}
