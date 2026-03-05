import CoreGraphics
import BaseKit

extension MaskLayer {
    func renderToMaskImage(scale: CGFloat) -> CGImage? {
        let width = Int(ceil(bounds.width * Double(scale)))
        let height = Int(ceil(bounds.height * Double(scale)))
        let contentTransform = CGAffineTransform(scaleX: scale, y: scale)
            .translatedBy(x: CGFloat(-bounds.x), y: CGFloat(-bounds.y))

        guard let rgbaImage = shapes.renderToImage(
            width: width, height: height,
            contentTransform: contentTransform
        ) else { return nil }

        // Convert RGBA to luminance grayscale
        guard let rgbaData = rgbaImage.dataProvider?.data,
              let pixelPtr = CFDataGetBytePtr(rgbaData) else { return nil }
        let pixelCount = width * height
        var grayscale = [UInt8](repeating: 0, count: pixelCount)
        for i in 0..<pixelCount {
            let r = Double(pixelPtr[i * 4]) / 255.0
            let g = Double(pixelPtr[i * 4 + 1]) / 255.0
            let b = Double(pixelPtr[i * 4 + 2]) / 255.0
            let a = Double(pixelPtr[i * 4 + 3]) / 255.0
            // SVG luminance formula (premultiplied, so unpremultiply first)
            let linearR = a > 0 ? r / a : 0
            let linearG = a > 0 ? g / a : 0
            let linearB = a > 0 ? b / a : 0
            let luminance = (0.2126 * linearR + 0.7152 * linearG + 0.0722 * linearB) * a
            grayscale[i] = UInt8(min(luminance * 255.0, 255.0))
        }

        // Create grayscale CGImage for use with context.clip(to:mask:)
        return grayscale.withUnsafeMutableBufferPointer { buffer in
            let graySpace = CGColorSpaceCreateDeviceGray()
            guard let grayContext = CGContext(
                data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width,
                space: graySpace,
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return nil }
            return grayContext.makeImage()
        }
    }
}
