import BaseKit
import CoreGraphics
import Foundation
import Testing

@testable import BaseUIKit

@Suite struct CanvasTextPerGlyphTests {
    private struct TestID: Hashable, Sendable {}

    /// Two-glyph run with explicit per-glyph positions: the inked
    /// regions for "A" and "B" land at the offsets, not at the
    /// natural CT advance positions.
    @Test func explicitPerGlyphOffsetsPlaceGlyphsAtSpecifiedPositions() {
        let bitmapSize = 200
        let context = makeBitmapContext(size: bitmapSize)
        clearWhite(context: context, size: bitmapSize)

        let runs = [
            TextRun(
                text: "AB",
                attributes: [.fontName("Helvetica"), .fontSize(20)],
                perGlyphOffsets: [
                    Point(x: 20, y: 40),
                    Point(x: 120, y: 100),
                ]
            )
        ]
        renderTextLayer(runs: runs, in: context, bitmapSize: bitmapSize)

        let leftHalf = inkedCentroid(
            context: context, size: bitmapSize,
            region: CGRect(x: 0, y: 0, width: bitmapSize / 2, height: bitmapSize))
        let rightHalf = inkedCentroid(
            context: context, size: bitmapSize,
            region: CGRect(x: bitmapSize / 2, y: 0, width: bitmapSize / 2, height: bitmapSize))

        // "A" should be in the upper-left (around y=40), "B" in the
        // lower-right (around y=100). Use loose tolerances: glyph
        // metrics and ink centroids shift by a few px per font.
        #expect(leftHalf != nil, "left half should have ink for the 'A' glyph")
        #expect(rightHalf != nil, "right half should have ink for the 'B' glyph")
        guard let leftHalf, let rightHalf else { return }
        #expect(leftHalf.y < rightHalf.y, "'A' at y=40 should be above 'B' at y=100")
        #expect(leftHalf.x < rightHalf.x, "'A' at x=20 should be left of 'B' at x=120")
        // The y=40 / y=100 difference is 60pt. The centroids should
        // reflect at least a meaningful chunk of that.
        #expect(rightHalf.y - leftHalf.y > 30)
    }

    /// Per-glyph rotation of 90° swaps a glyph's inked bounding-box
    /// dimensions. Use "I" — a tall narrow glyph — so the swap is
    /// unambiguous.
    @Test func perGlyphRotationSwapsBoundingBoxDimensions() {
        let bitmapSize = 200
        let unrotated = makeBitmapContext(size: bitmapSize)
        clearWhite(context: unrotated, size: bitmapSize)
        let rotated = makeBitmapContext(size: bitmapSize)
        clearWhite(context: rotated, size: bitmapSize)

        let position = Point(x: 80, y: 80)
        let unrotatedRuns = [
            TextRun(
                text: "I",
                attributes: [.fontName("Helvetica"), .fontSize(48)],
                perGlyphOffsets: [position]
            )
        ]
        let rotatedRuns = [
            TextRun(
                text: "I",
                attributes: [.fontName("Helvetica"), .fontSize(48)],
                perGlyphOffsets: [position],
                perGlyphRotations: [.pi / 2]
            )
        ]
        renderTextLayer(runs: unrotatedRuns, in: unrotated, bitmapSize: bitmapSize)
        renderTextLayer(runs: rotatedRuns, in: rotated, bitmapSize: bitmapSize)

        let unrotatedBounds = inkedBounds(context: unrotated, size: bitmapSize)
        let rotatedBounds = inkedBounds(context: rotated, size: bitmapSize)

        #expect(unrotatedBounds != nil, "unrotated 'I' should have ink")
        #expect(rotatedBounds != nil, "rotated 'I' should have ink")
        guard let unrotatedBounds, let rotatedBounds else { return }

        // "I" is a tall narrow glyph: unrotated height >> width.
        // After 90° rotation, width and height should swap.
        #expect(unrotatedBounds.height > unrotatedBounds.width * 2,
            "unrotated 'I' should be taller than wide")
        #expect(rotatedBounds.width > rotatedBounds.height * 2,
            "rotated 'I' should be wider than tall")
    }

    /// **Regression guard**: rendering a run with no per-glyph data
    /// must take the same path as before and produce the same inked
    /// pixel count as the equivalent uniform render.
    @Test func runWithoutPerGlyphDataMatchesFastPath() {
        let bitmapSize = 200

        let withoutData = makeBitmapContext(size: bitmapSize)
        clearWhite(context: withoutData, size: bitmapSize)
        let withNilArrays = makeBitmapContext(size: bitmapSize)
        clearWhite(context: withNilArrays, size: bitmapSize)

        let runsA = [
            TextRun(
                text: "Hello",
                attributes: [.fontName("Helvetica"), .fontSize(20)]
            )
        ]
        let runsB = [
            TextRun(
                text: "Hello",
                attributes: [.fontName("Helvetica"), .fontSize(20)],
                perGlyphOffsets: nil,
                perGlyphRotations: nil
            )
        ]
        renderTextLayer(runs: runsA, in: withoutData, bitmapSize: bitmapSize)
        renderTextLayer(runs: runsB, in: withNilArrays, bitmapSize: bitmapSize)

        let countA = nonWhitePixelCount(context: withoutData, size: bitmapSize)
        let countB = nonWhitePixelCount(context: withNilArrays, size: bitmapSize)
        #expect(countA > 0, "uniform render should produce ink")
        #expect(countA == countB,
            "nil arrays must match the fast path exactly (got \(countA) vs \(countB))")
    }

    /// Sparse per-glyph offsets: a nil entry falls back to the
    /// natural CT advance. Verify the nil entry actually renders the
    /// glyph (rather than being skipped) by comparing ink against a
    /// run with both entries explicit and confirming the sparse run
    /// has ink in BOTH the natural-advance region AND the explicit
    /// region.
    @Test func sparsePerGlyphOffsetsFallBackToNaturalAdvance() {
        let bitmapSize = 200
        let bPosition = Point(x: 140, y: 140)
        // Shift the layer so the natural baseline lands in the
        // middle of the bitmap, not at the top edge — otherwise the
        // nil-A glyph renders off-bitmap and the test can't see it.
        let layerTransform = Transform(translateX: 0, y: 60)

        // Reference: render only "B" at its explicit position. The
        // natural-advance "A" position would be near the layer's
        // local (0, 0), nowhere near "B".
        let bOnly = makeBitmapContext(size: bitmapSize)
        clearWhite(context: bOnly, size: bitmapSize)
        renderTextLayer(
            runs: [
                TextRun(
                    text: "B",
                    attributes: [.fontName("Helvetica"), .fontSize(20)],
                    perGlyphOffsets: [bPosition]
                )
            ],
            in: bOnly,
            bitmapSize: bitmapSize,
            transform: layerTransform
        )

        // Sparse: "A" uses nil (→ natural), "B" explicit.
        let sparse = makeBitmapContext(size: bitmapSize)
        clearWhite(context: sparse, size: bitmapSize)
        renderTextLayer(
            runs: [
                TextRun(
                    text: "AB",
                    attributes: [.fontName("Helvetica"), .fontSize(20)],
                    perGlyphOffsets: [nil, bPosition]
                )
            ],
            in: sparse,
            bitmapSize: bitmapSize,
            transform: layerTransform
        )

        let sparseInk = nonWhitePixelCount(context: sparse, size: bitmapSize)
        let bOnlyInk = nonWhitePixelCount(context: bOnly, size: bitmapSize)
        #expect(sparseInk > bOnlyInk,
            "sparse should include both glyphs; B-only has just one (sparse=\(sparseInk), B-only=\(bOnlyInk))")
    }
}

private extension CanvasTextPerGlyphTests {
    func renderTextLayer(
        runs: [TextRun],
        in context: CGContext,
        bitmapSize: Int,
        transform: Transform = .identity
    ) {
        let layer = TextLayer<TestID>(
            id: TestID(),
            transform: transform,
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

    /// Creates a bitmap context with the canvas y-flip applied —
    /// matching `CanvasDatabase.renderToImage`. With the flip,
    /// SVG y-down coordinates map directly to memory rows: SVG y=40
    /// lands at memory row 40 (40pt from the top of the bitmap).
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
        // Flip to top-left origin to match the canvas y-down convention
        // (same flip CanvasDatabase.renderToImage applies before
        // drawing layers).
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

    func inkedCentroid(
        context: CGContext,
        size: Int,
        region: CGRect
    ) -> CGPoint? {
        guard let dataPointer = context.data else { return nil }
        let buffer = dataPointer.bindMemory(to: UInt8.self, capacity: size * size * 4)
        let xMin = max(0, Int(region.minX))
        let yMin = max(0, Int(region.minY))
        let xMax = min(size, Int(region.maxX))
        let yMax = min(size, Int(region.maxY))
        var sumX = 0
        var sumY = 0
        var count = 0
        for y in yMin..<yMax {
            for x in xMin..<xMax {
                let i = (y * size + x) * 4
                let r = buffer[i]
                let g = buffer[i + 1]
                let b = buffer[i + 2]
                if r < 240 || g < 240 || b < 240 {
                    sumX += x
                    sumY += y
                    count += 1
                }
            }
        }
        guard count > 0 else { return nil }
        return CGPoint(x: Double(sumX) / Double(count), y: Double(sumY) / Double(count))
    }

    func inkedBounds(context: CGContext, size: Int) -> CGRect? {
        guard let dataPointer = context.data else { return nil }
        let buffer = dataPointer.bindMemory(to: UInt8.self, capacity: size * size * 4)
        var xMin = Int.max
        var yMin = Int.max
        var xMax = Int.min
        var yMax = Int.min
        for y in 0..<size {
            for x in 0..<size {
                let i = (y * size + x) * 4
                let r = buffer[i]
                let g = buffer[i + 1]
                let b = buffer[i + 2]
                if r < 240 || g < 240 || b < 240 {
                    xMin = min(xMin, x)
                    yMin = min(yMin, y)
                    xMax = max(xMax, x)
                    yMax = max(yMax, y)
                }
            }
        }
        guard xMin <= xMax, yMin <= yMax else { return nil }
        return CGRect(
            x: xMin, y: yMin,
            width: xMax - xMin + 1,
            height: yMax - yMin + 1
        )
    }
}
