import BaseKit
import CoreGraphics
import CoreText
import XCTest

@testable import BaseUIKit

/// Reproduces the on-canvas share-badge bug: when a `TextLayer` runs
/// "🔗 N" through `Font(name: "Helvetica", size: 11)`, the layout
/// reserves the chain emoji's advance width but no glyph rasterizes —
/// the badge displays just "N" with a blank to the left.
///
/// Cause: `CanvasText.locked_drawUniform` renders text by converting
/// glyphs to a `CGPath` and filling it with the layer's decorations.
/// Color-bitmap fonts like Apple Color Emoji return nil from
/// `CTFontCreatePathForGlyph`, so those glyphs never make it into the
/// path and never appear on screen.
final class CanvasTextEmojiRenderingTests: XCTestCase {
    /// Sanity baseline: ASCII text in Helvetica DOES render visibly. If
    /// this fails, the test harness or the rendering pipeline is broken
    /// at a more fundamental level than the emoji issue.
    func testHelveticaTextRendersToBitmap() {
        let pixels = renderToBitmap(text: "AB", fontSize: 24)
        XCTAssertGreaterThan(
            pixels.nonWhiteCount, 0,
            "Expected ASCII text in Helvetica to produce visible pixels"
        )
    }

    /// The bug: the chain emoji renders to zero pixels. CoreText
    /// substitutes Apple Color Emoji as the cascade font (verified by
    /// `FontEmojiCascadeTests`), but `locked_drawUniform`'s path-based
    /// pipeline drops bitmap glyphs.
    func testChainEmojiRendersToBitmap() {
        let pixels = renderToBitmap(text: "🔗", fontSize: 24)
        XCTAssertGreaterThan(
            pixels.nonWhiteCount, 0,
            "Expected the chain emoji to render visibly via Apple Color Emoji "
                + "fallback. Got an all-white bitmap, meaning the glyph never made "
                + "it from CoreText to the canvas. Pixel count: \(pixels.totalCount)."
        )
    }

    // MARK: - Helpers

    private struct RenderedPixels {
        let nonWhiteCount: Int
        let totalCount: Int
    }

    private func renderToBitmap(text: String, fontSize: Double) -> RenderedPixels {
        let bitmapSize = 64
        let context = makeBitmapContext(size: bitmapSize)

        // White background.
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: bitmapSize, height: bitmapSize))

        let attributes: [TextRun.Attribute] = [
            .fontName("Helvetica"),
            .fontSize(fontSize),
        ]
        let textLayer = TextLayer<TestID>(
            id: TestID(),
            transform: BaseKit.Transform(translateX: 0, y: 0),
            position: .zero,
            opacity: 1.0,
            blendMode: .normal,
            isVisible: true,
            decorations: [Decoration.fill(Fill(paint: .solid(.black)))],
            runs: [TextRun(text: text, attributes: attributes)],
            autosize: true,
            width: 200
        )
        let canvasText: CanvasText<TestID> = CanvasText(layer: textLayer)
        let cache: RenderingCache? = nil
        canvasText.draw(
            CGRect(x: 0, y: 0, width: bitmapSize, height: bitmapSize),
            into: context,
            atScale: 1.0,
            renderingCache: cache
        )

        return countNonWhite(context: context, size: bitmapSize)
    }

    private func makeBitmapContext(size: Int) -> CGContext {
        let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo:
                CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        )!
        return context
    }

    private func countNonWhite(context: CGContext, size: Int) -> RenderedPixels {
        guard let dataPointer = context.data else {
            return RenderedPixels(nonWhiteCount: 0, totalCount: 0)
        }
        let total = size * size
        let buffer = dataPointer.bindMemory(to: UInt8.self, capacity: total * 4)
        var nonWhite = 0
        for i in 0..<total {
            let r = buffer[i * 4]
            let g = buffer[i * 4 + 1]
            let b = buffer[i * 4 + 2]
            // Treat anything noticeably below pure white as a rendered pixel.
            if r < 240 || g < 240 || b < 240 {
                nonWhite += 1
            }
        }
        return RenderedPixels(nonWhiteCount: nonWhite, totalCount: total)
    }
}

private struct TestID: Hashable, Sendable {
    let value: UUID

    init() {
        self.value = UUID()
    }
}
