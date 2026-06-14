import BaseKit
import CoreGraphics
import Foundation
import Testing

@testable import BaseUIKit

@Suite struct CanvasTextBlockListTests {
    private struct TestID: Hashable, Sendable {}

    /// Two-block layer: a framesetter block ("HELLO") drawn at the
    /// layer's natural baseline, plus a per-glyph block ("X") placed
    /// at an explicit far-away offset. Both must render — confirms
    /// `locked_drawSelf` iterates blocks and routes each to its native
    /// pipeline instead of picking one whole-layer mode.
    @Test func framesetterBlockAndPerGlyphBlockBothRender() {
        let bitmapSize = 200
        let context = makeBitmapContext(size: bitmapSize)
        clearWhite(context: context, size: bitmapSize)

        let blocks: [TextBlock] = [
            .framesetter(
                runs: [
                    TextRun(
                        text: "HELLO",
                        attributes: [.fontName("Helvetica"), .fontSize(24)]
                    )
                ],
                anchor: .zero
            ),
            .perGlyph(
                runs: [
                    TextRun(
                        text: "X",
                        attributes: [.fontName("Helvetica"), .fontSize(24)],
                        perGlyphOffsets: [Point(x: 150, y: 150)]
                    )
                ]
            ),
        ]
        renderTextLayer(blocks: blocks, in: context, bitmapSize: bitmapSize)

        // Framesetter portion lands near the top-left; per-glyph X lands
        // near (150, 150). Probe disjoint regions for ink in each.
        let topLeft = inkedCount(
            context: context, size: bitmapSize,
            region: CGRect(x: 0, y: 0, width: 100, height: 100))
        let bottomRight = inkedCount(
            context: context, size: bitmapSize,
            region: CGRect(x: 120, y: 120, width: 80, height: 80))

        #expect(topLeft > 0, "framesetter HELLO block should ink the top-left")
        #expect(bottomRight > 0, "per-glyph X block should ink near (150, 150)")
    }

    /// **Regression guard**: a layer built with the legacy `runs:`
    /// initializer auto-wraps into a single block, and that block path
    /// produces the same ink as a layer built with `blocks:`. Confirms
    /// the convenience init's framesetter wrap matches the explicit
    /// single-block form pixel-for-pixel.
    @Test func runsInitMatchesSingleFramesetterBlock() {
        let bitmapSize = 200
        let runsCtx = makeBitmapContext(size: bitmapSize)
        clearWhite(context: runsCtx, size: bitmapSize)
        let blocksCtx = makeBitmapContext(size: bitmapSize)
        clearWhite(context: blocksCtx, size: bitmapSize)

        let runs = [
            TextRun(
                text: "Hello world",
                attributes: [.fontName("Helvetica"), .fontSize(18)]
            )
        ]
        renderTextLayer(runs: runs, in: runsCtx, bitmapSize: bitmapSize)
        renderTextLayer(
            blocks: [.framesetter(runs: runs, anchor: .zero)],
            in: blocksCtx, bitmapSize: bitmapSize)

        let runsInk = nonWhitePixelCount(context: runsCtx, size: bitmapSize)
        let blocksInk = nonWhitePixelCount(context: blocksCtx, size: bitmapSize)
        #expect(runsInk > 0)
        #expect(runsInk == blocksInk,
            "single-block layer must match flat-runs layer pixel-for-pixel (got \(runsInk) vs \(blocksInk))")
    }
}

private extension CanvasTextBlockListTests {
    func renderTextLayer(
        blocks: [TextBlock],
        in context: CGContext,
        bitmapSize: Int
    ) {
        let layer = TextLayer<TestID>(
            id: TestID(),
            transform: .identity,
            position: .zero,
            opacity: 1.0,
            blendMode: .normal,
            isVisible: true,
            decorations: [Decoration.fill(Fill(paint: .solid(.black)))],
            blocks: blocks,
            shouldScaleWithZoom: true,
            autosize: true,
            width: Double(bitmapSize)
        )
        CanvasText<TestID>(layer: layer).draw(
            CGRect(x: 0, y: 0, width: Double(bitmapSize), height: Double(bitmapSize)),
            into: context,
            atScale: 1.0,
            renderingCache: nil
        )
    }

    func renderTextLayer(
        runs: [TextRun],
        in context: CGContext,
        bitmapSize: Int
    ) {
        let layer = TextLayer<TestID>(
            id: TestID(),
            transform: .identity,
            position: .zero,
            opacity: 1.0,
            blendMode: .normal,
            isVisible: true,
            decorations: [Decoration.fill(Fill(paint: .solid(.black)))],
            runs: runs,
            shouldScaleWithZoom: true,
            autosize: true,
            width: Double(bitmapSize)
        )
        CanvasText<TestID>(layer: layer).draw(
            CGRect(x: 0, y: 0, width: Double(bitmapSize), height: Double(bitmapSize)),
            into: context,
            atScale: 1.0,
            renderingCache: nil
        )
    }

    func makeBitmapContext(size: Int) -> CGContext {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            fatalError("Failed to create bitmap context")
        }
        context.translateBy(x: 0, y: CGFloat(size))
        context.scaleBy(x: 1, y: -1)
        return context
    }

    func clearWhite(context: CGContext, size: Int) {
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
    }

    func nonWhitePixelCount(context: CGContext, size: Int) -> Int {
        guard let dataPointer = context.data else { return 0 }
        let buffer = dataPointer.bindMemory(to: UInt8.self, capacity: size * size * 4)
        var count = 0
        for i in 0..<(size * size) {
            let r = buffer[i * 4]
            let g = buffer[i * 4 + 1]
            let b = buffer[i * 4 + 2]
            if r < 240 || g < 240 || b < 240 {
                count += 1
            }
        }
        return count
    }

    func inkedCount(context: CGContext, size: Int, region: CGRect) -> Int {
        guard let dataPointer = context.data else { return 0 }
        let buffer = dataPointer.bindMemory(to: UInt8.self, capacity: size * size * 4)
        let xMin = max(0, Int(region.minX))
        let yMin = max(0, Int(region.minY))
        let xMax = min(size, Int(region.maxX))
        let yMax = min(size, Int(region.maxY))
        var count = 0
        for y in yMin..<yMax {
            for x in xMin..<xMax {
                let i = (y * size + x) * 4
                let r = buffer[i]
                let g = buffer[i + 1]
                let b = buffer[i + 2]
                if r < 240 || g < 240 || b < 240 {
                    count += 1
                }
            }
        }
        return count
    }
}
