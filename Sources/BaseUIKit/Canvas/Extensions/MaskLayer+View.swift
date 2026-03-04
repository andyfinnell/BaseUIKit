import Foundation
import CoreGraphics
import BaseKit

extension MaskLayer {
    func renderToMaskImage(scale: CGFloat) -> CGImage? {
        let width = Int(ceil(bounds.width * Double(scale)))
        let height = Int(ceil(bounds.height * Double(scale)))
        guard width > 0, height > 0 else { return nil }

        // Create offscreen RGBA context
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: width, height: height,
                  bitsPerComponent: 8, bytesPerRow: width * 4,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }

        // Set up coordinate system: map mask bounds to context
        context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
        context.translateBy(x: CGFloat(-bounds.x), y: CGFloat(-bounds.y))

        // Render each mask shape
        for shape in shapes {
            context.saveGState()
            context.setAlpha(CGFloat(shape.opacity))
            context.concatenate(shape.transform.toCG)
            for decoration in shape.decorations {
                shape.path.set(in: context)
                decoration.render(into: context, atScale: 1.0)
            }
            context.restoreGState()
        }

        // Convert RGBA to luminance grayscale
        guard let pixelData = context.data else { return nil }
        let pixels = pixelData.bindMemory(to: UInt8.self, capacity: width * height * 4)
        var grayscale = [UInt8](repeating: 0, count: width * height)
        for i in 0..<(width * height) {
            let r = Double(pixels[i * 4]) / 255.0
            let g = Double(pixels[i * 4 + 1]) / 255.0
            let b = Double(pixels[i * 4 + 2]) / 255.0
            let a = Double(pixels[i * 4 + 3]) / 255.0
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
