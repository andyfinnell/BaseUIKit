import BaseKit
import CoreGraphics
import Foundation
import Testing

@testable import BaseUIKit

@Suite struct CanvasTextScalingTests {
    /// `shouldScaleWithZoom: false` on a `TextLayer` should render at a
    /// constant screen-pixel size regardless of canvas zoom. Compared to the
    /// default `true` (where the font is doc-space and so doubles in size
    /// when zoom doubles), the screen-space variant should produce a
    /// noticeably smaller inked footprint when both are drawn at the same
    /// scale > 1.
    @Test func screenSpaceTextRendersSmallerThanDocSpaceAtZoom() {
        let docSpacePixels = renderTextPixels(scale: 2.0, shouldScaleWithZoom: true)
        let screenSpacePixels = renderTextPixels(scale: 2.0, shouldScaleWithZoom: false)

        #expect(docSpacePixels > 0)
        #expect(screenSpacePixels > 0)
        // At scale 2x, doc-space text covers roughly 4× the area of
        // screen-space text (linear 2× → area 4×). Assert a conservative
        // 2× lower bound so font metrics quirks don't make this flaky.
        #expect(docSpacePixels >= screenSpacePixels * 2)
    }

    /// A `shouldScaleWithZoom: false` render at scale 2x should produce a
    /// similar inked footprint to a default (`true`) render at scale 1x —
    /// because the descale cancels the outer zoom, leaving the text at its
    /// nominal screen size.
    @Test func screenSpaceTextAtZoomMatchesDocSpaceAtUnitScale() {
        let unitScaleDoc = renderTextPixels(scale: 1.0, shouldScaleWithZoom: true)
        let zoomedScreenSpace = renderTextPixels(scale: 2.0, shouldScaleWithZoom: false)

        #expect(unitScaleDoc > 0)
        #expect(zoomedScreenSpace > 0)
        // Allow a wide tolerance: font hinting and sub-pixel positioning
        // change between scales, but the values should be within ~50% of
        // each other rather than 4× apart.
        let ratio = Double(zoomedScreenSpace) / Double(unitScaleDoc)
        #expect(ratio > 0.5)
        #expect(ratio < 2.0)
    }

    /// The screen-space text label and its derived screen-space pill must
    /// share the same center at every zoom level — otherwise the gradient
    /// share badge (and the drag HUD, and the snap distance label) drift
    /// out of their pill as the user zooms in.
    ///
    /// The pill bezier is computed from `typographicBounds`, which has the
    /// font's baseline offset baked into local-space y. The label's
    /// rendering used to apply the baseline offset via its `transform`
    /// (pre-1/scale) — so at zoom > 1 the offset showed up as `zoom ×
    /// offset` view-px on the label but only `offset` view-px on the pill.
    /// The fix moves the label's baseline offset into post-1/scale local
    /// space so both contribute the same view-px shift.
    @Test func screenSpaceLabelAndPillStayCenteredAtAnyZoom() {
        for scale in [1.0, 2.0, 3.0] {
            let labelCenter = labelCenterOfMass(scale: CGFloat(scale))
            let pillCenter = pillCenterOfMass(scale: CGFloat(scale))
            #expect(
                abs(labelCenter.x - pillCenter.x) <= 1.5,
                "x drift at scale \(scale): label \(labelCenter.x) pill \(pillCenter.x)"
            )
            #expect(
                abs(labelCenter.y - pillCenter.y) <= 1.5,
                "y drift at scale \(scale): label \(labelCenter.y) pill \(pillCenter.y)"
            )
        }
    }
}

private extension CanvasTextScalingTests {
    func renderTextPixels(scale: CGFloat, shouldScaleWithZoom: Bool) -> Int {
        let bitmapSize = 128
        let context = makeBitmapContext(size: bitmapSize)
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: bitmapSize, height: bitmapSize))
        context.scaleBy(x: scale, y: scale)

        let layer = TextLayer<TestID>(
            id: TestID(),
            transform: BaseKit.Transform(translateX: 10, y: 30),
            opacity: 1.0,
            blendMode: .normal,
            isVisible: true,
            decorations: [Decoration.fill(Fill(paint: .solid(.black)))],
            runs: [
                TextRun(
                    text: "ABC",
                    attributes: [.fontName("Helvetica"), .fontSize(16)]
                )
            ],
            shouldScaleWithZoom: shouldScaleWithZoom,
            autosize: true,
            width: 200
        )
        let canvasText: CanvasText<TestID> = CanvasText(layer: layer)
        canvasText.draw(
            CGRect(x: 0, y: 0, width: Double(bitmapSize) / scale, height: Double(bitmapSize) / scale),
            into: context,
            atScale: scale,
            renderingCache: nil
        )
        return countNonWhitePixels(context: context, size: bitmapSize)
    }

    func makeBitmapContext(size: Int) -> CGContext {
        CGContext(
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
    }

    func countNonWhitePixels(context: CGContext, size: Int) -> Int {
        guard let dataPointer = context.data else { return 0 }
        let total = size * size
        let buffer = dataPointer.bindMemory(to: UInt8.self, capacity: total * 4)
        var nonWhite = 0
        for i in 0..<total {
            let r = buffer[i * 4]
            let g = buffer[i * 4 + 1]
            let b = buffer[i * 4 + 2]
            if r < 240 || g < 240 || b < 240 {
                nonWhite += 1
            }
        }
        return nonWhite
    }

    func labelCenterOfMass(scale: CGFloat) -> CGPoint {
        let bitmapSize = 128
        let context = makeBitmapContext(size: bitmapSize)
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: bitmapSize, height: bitmapSize))
        context.scaleBy(x: scale, y: scale)

        let layer = TextLayer<TestID>(
            id: TestID(),
            transform: BaseKit.Transform(translateX: 30, y: 30),
            opacity: 1.0,
            blendMode: .normal,
            isVisible: true,
            decorations: [Decoration.fill(Fill(paint: .solid(.black)))],
            runs: [
                TextRun(
                    text: "ABC",
                    attributes: [.fontName("Helvetica"), .fontSize(16)]
                )
            ],
            shouldScaleWithZoom: false,
            autosize: true,
            width: 200
        )
        CanvasText<TestID>(layer: layer).draw(
            CGRect(x: 0, y: 0, width: Double(bitmapSize) / scale, height: Double(bitmapSize) / scale),
            into: context,
            atScale: scale,
            renderingCache: nil
        )
        return centerOfMass(context: context, size: bitmapSize)
    }

    func pillCenterOfMass(scale: CGFloat) -> CGPoint {
        let bitmapSize = 128
        let context = makeBitmapContext(size: bitmapSize)
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: bitmapSize, height: bitmapSize))
        context.scaleBy(x: scale, y: scale)

        // Mirrors the gradient share badge / drag HUD / distance label
        // pill factory: typographic bounds inset by (-6, -3), local-space
        // bezier, layer transform carries the same anchor as the label,
        // `shouldScaleWithZoom: false`.
        let typographicBounds = typographicBoundsForLabel()
        let pillRect = typographicBounds.insetBy(dx: -6, dy: -3)
        let bezier = BezierPath(
            roundedRect: pillRect,
            cornerRadius: pillRect.height / 2
        )
        let pillLayer = PathLayer<TestID>(
            id: TestID(),
            transform: BaseKit.Transform(translateX: 30, y: 30),
            decorations: [Decoration.fill(Fill(paint: .solid(.black)))],
            bezier: bezier,
            shouldScaleWithZoom: false
        )
        CanvasPath<TestID>(layer: pillLayer).draw(
            CGRect(x: 0, y: 0, width: Double(bitmapSize) / scale, height: Double(bitmapSize) / scale),
            into: context,
            atScale: scale,
            renderingCache: nil
        )
        return centerOfMass(context: context, size: bitmapSize)
    }

    func typographicBoundsForLabel() -> Rect {
        let layer = TextLayer<TestID>(
            id: TestID(),
            transform: BaseKit.Transform(translateX: 0, y: 0),
            opacity: 1.0,
            blendMode: .normal,
            isVisible: true,
            decorations: [Decoration.fill(Fill(paint: .solid(.black)))],
            runs: [
                TextRun(
                    text: "ABC",
                    attributes: [.fontName("Helvetica"), .fontSize(16)]
                )
            ],
            shouldScaleWithZoom: false,
            autosize: true,
            width: 200
        )
        return Rect(CanvasText<TestID>(layer: layer).typographicBounds ?? .zero)
    }

    func centerOfMass(context: CGContext, size: Int) -> CGPoint {
        guard let dataPointer = context.data else { return .zero }
        let total = size * size
        let buffer = dataPointer.bindMemory(to: UInt8.self, capacity: total * 4)
        var sumX = 0
        var sumY = 0
        var count = 0
        for y in 0..<size {
            for x in 0..<size {
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
        guard count > 0 else { return .zero }
        return CGPoint(x: Double(sumX) / Double(count), y: Double(sumY) / Double(count))
    }
}

private struct TestID: Hashable, Sendable {
    let value: UUID

    init() {
        self.value = UUID()
    }
}
