import BaseKit
import CoreGraphics
import Foundation
import Testing

@testable import BaseUIKit

/// `hitPadding` on `PathLayer` / `TextLayer` fattens the hit-test region by a
/// screen-pt amount that stays constant across zoom. `hitOnly` on `PathLayer`
/// keeps the layer hittable while excluding it from the draw pass and
/// invalidation rects.
@Suite struct CanvasHitPaddingTests {
    // MARK: - PathLayer.hitPadding

    /// `hitPadding == 0` preserves the prior contains/distance behavior: a
    /// point inside the filled rect hits; a point just outside misses.
    @Test func pathHitPaddingZeroPreservesBaselineBehavior() {
        let path = makeFilledRectPath(anchor: Self.anchor, hitPadding: 0)
        // Inside the 10x10 rect centered on anchor.
        #expect(path.hitLayer(at: Self.anchor, atScale: 1.0, including: { _ in true }) != nil)
        // Two pt outside the rect's right edge.
        #expect(
            path.hitLayer(at: CGPoint(x: Self.anchor.x + Self.markerSize / 2 + 2, y: Self.anchor.y), atScale: 1.0, including: { _ in true }) == nil
        )
    }

    /// A filled path with hitPadding=5 hits up to 5pt outside its edges at
    /// zoom=1 (and proportionally more doc-pt at lower zoom).
    @Test func pathHitPaddingDilatesFilledHitArea() {
        let path = makeFilledRectPath(anchor: Self.anchor, hitPadding: 5)
        // 4pt outside the right edge: padded hit-test should succeed.
        #expect(
            path.hitLayer(at: CGPoint(x: Self.anchor.x + Self.markerSize / 2 + 4, y: Self.anchor.y), atScale: 1.0, including: { _ in true }) != nil
        )
        // 6pt outside: still misses (just past padding).
        #expect(
            path.hitLayer(at: CGPoint(x: Self.anchor.x + Self.markerSize / 2 + 6, y: Self.anchor.y), atScale: 1.0, including: { _ in true }) == nil
        )
    }

    /// An unfilled stroked path (1pt stroke) with hitPadding=5 hits up to
    /// (strokeWidth + padding) doc-pt from the path.
    @Test func pathHitPaddingDilatesStrokedHitArea() {
        let path = makeStrokedLinePath(
            start: CGPoint(x: 10, y: 50),
            end: CGPoint(x: 90, y: 50),
            strokeWidth: 1,
            hitPadding: 5
        )
        // Vertically 4pt off the line: hits (within 0.5 + 5).
        #expect(path.hitLayer(at: CGPoint(x: 50, y: 54), atScale: 1.0, including: { _ in true }) != nil)
        // 7pt off: misses.
        #expect(path.hitLayer(at: CGPoint(x: 50, y: 57), atScale: 1.0, including: { _ in true }) == nil)
    }

    /// Padding is screen-pt, not doc-pt: at zoom 2.0 the doc-space radius is
    /// halved, so a hit 4pt off the line in doc-space (= 8pt screen) misses
    /// for hitPadding=5, but 2pt off (= 4pt screen) hits.
    @Test func pathHitPaddingIsScreenPtAcrossZoom() {
        let path = makeStrokedLinePath(
            start: CGPoint(x: 10, y: 50),
            end: CGPoint(x: 90, y: 50),
            strokeWidth: 1,
            hitPadding: 5
        )
        let scale: CGFloat = 2.0
        // 2pt doc-off (= 4pt screen): hits (within 0.5 + 5/2 = 3 doc-pt).
        #expect(path.hitLayer(at: CGPoint(x: 50, y: 52), atScale: scale, including: { _ in true }) != nil)
        // 4pt doc-off (= 8pt screen): misses (beyond 0.5 + 2.5 = 3 doc-pt).
        #expect(path.hitLayer(at: CGPoint(x: 50, y: 54), atScale: scale, including: { _ in true }) == nil)
    }

    // MARK: - PathLayer.hitOnly

    /// A hit-only PathLayer reports `willDrawRect == .zero` and produces zero
    /// pixels on the canvas even though it's still hit-testable.
    @Test func pathHitOnlySkipsDrawAndInvalidation() {
        let path = makeFilledRectPath(
            anchor: Self.anchor,
            hitPadding: 0,
            hitOnly: true
        )

        // willDrawRect is .zero before any draw call.
        #expect(path.willDrawRect == .zero)

        // After drawing, no pixels should land on the bitmap.
        let bitmapSize = 64
        let context = makeBitmapContext(size: bitmapSize)
        path.draw(
            CGRect(x: 0, y: 0, width: bitmapSize, height: bitmapSize),
            into: context,
            atScale: 1.0,
            renderingCache: nil
        )
        #expect(isBitmapAllWhite(context: context, size: bitmapSize))

        // But the layer remains hit-testable.
        #expect(path.hitLayer(at: Self.anchor, atScale: 1.0, including: { _ in true }) != nil)

        // willDrawRect stays .zero even after drawing.
        #expect(path.willDrawRect == .zero)
    }

    /// hitOnly + hitPadding stack: a hit-only line with hitPadding=5 is
    /// hittable inside the 5pt padding band even though nothing draws.
    @Test func pathHitOnlyAndHitPaddingStack() {
        let path = makeStrokedLinePath(
            start: CGPoint(x: 10, y: 50),
            end: CGPoint(x: 90, y: 50),
            strokeWidth: 0,
            hitPadding: 5,
            hitOnly: true
        )
        #expect(path.willDrawRect == .zero)
        #expect(path.hitLayer(at: CGPoint(x: 50, y: 54), atScale: 1.0, including: { _ in true }) != nil)
        #expect(path.hitLayer(at: CGPoint(x: 50, y: 56), atScale: 1.0, including: { _ in true }) == nil)

        // Nothing drawn.
        let bitmapSize = 64
        let context = makeBitmapContext(size: bitmapSize)
        path.draw(
            CGRect(x: 0, y: 0, width: bitmapSize, height: bitmapSize),
            into: context,
            atScale: 1.0,
            renderingCache: nil
        )
        #expect(isBitmapAllWhite(context: context, size: bitmapSize))
    }

    // MARK: - Compose with screenOffset

    /// hitPadding composes with screenOffset: the padded region tracks the
    /// shifted geometry, not the original transform anchor.
    @Test func pathHitPaddingComposesWithScreenOffset() {
        let offset = Vector(dx: 10, dy: 0)
        let path = makeFilledRectPath(
            anchor: Self.anchor,
            screenOffset: offset,
            shouldScaleWithZoom: false,
            hitPadding: 5
        )
        let scale: CGFloat = 1.0
        // After the offset, the visual rect's right edge sits at
        // anchor.x + offset.dx + markerSize/2 = 30 + 10 + 5 = 45.
        let visualRight = Self.anchor.x + CGFloat(offset.dx) / scale + Self.markerSize / 2

        // 4pt past the shifted right edge: still hits via padding.
        #expect(
            path.hitLayer(at: CGPoint(x: visualRight + 4, y: Self.anchor.y), atScale: scale, including: { _ in true }) != nil
        )
        // 6pt past the shifted right edge: beyond padding, misses.
        #expect(
            path.hitLayer(at: CGPoint(x: visualRight + 6, y: Self.anchor.y), atScale: scale, including: { _ in true }) == nil
        )
    }

    // MARK: - TextLayer.hitPadding

    /// TextLayer.hitPadding dilates the typographic bounds in screen-pt.
    @Test func textHitPaddingDilatesContentBounds() {
        // Establish the baseline content bounds with padding=0.
        let baseline = makeTextCanvas(anchor: Self.anchor, hitPadding: 0)
        guard let baseBounds = baseline.typographicBounds else {
            Issue.record("typographicBounds nil")
            return
        }
        let visualRight = Self.anchor.x + baseBounds.maxX

        let padded = makeTextCanvas(anchor: Self.anchor, hitPadding: 5)
        // 3pt past the unpadded right edge: hits with padding.
        #expect(padded.hitLayer(at: CGPoint(x: visualRight + 3, y: Self.anchor.y), atScale: 1.0, including: { _ in true }) != nil)
        // Without padding, that same point misses.
        #expect(baseline.hitLayer(at: CGPoint(x: visualRight + 3, y: Self.anchor.y), atScale: 1.0, including: { _ in true }) == nil)
    }

    @Test func textHitPaddingIsScreenPtAcrossZoom() {
        let baseline = makeTextCanvas(anchor: Self.anchor, hitPadding: 0)
        guard let baseBounds = baseline.typographicBounds else {
            Issue.record("typographicBounds nil")
            return
        }
        let visualRight = Self.anchor.x + baseBounds.maxX

        // At 2x zoom, hitPadding=5 screen-pt ≈ 2.5 doc-pt.
        let padded = makeTextCanvas(anchor: Self.anchor, hitPadding: 5)
        // 2pt doc past the right edge (= 4pt screen): within padding.
        #expect(padded.hitLayer(at: CGPoint(x: visualRight + 2, y: Self.anchor.y), atScale: 2.0, including: { _ in true }) != nil)
        // 4pt doc past (= 8pt screen): beyond padding.
        #expect(padded.hitLayer(at: CGPoint(x: visualRight + 4, y: Self.anchor.y), atScale: 2.0, including: { _ in true }) == nil)
    }
}

private extension CanvasHitPaddingTests {
    static let anchor = CGPoint(x: 30, y: 30)
    static let markerSize: CGFloat = 10

    func makeFilledRectPath(
        anchor: CGPoint,
        screenOffset: Vector = .zero,
        shouldScaleWithZoom: Bool = true,
        hitPadding: CGFloat,
        hitOnly: Bool = false
    ) -> CanvasPath<TestID> {
        let layer = PathLayer<TestID>(
            id: TestID(),
            transform: BaseKit.Transform(translateX: anchor.x, y: anchor.y),
            screenOffset: screenOffset,
            decorations: [Decoration.fill(Fill(paint: .solid(.black)))],
            bezier: BezierPath(
                rect: Rect(
                    x: -Self.markerSize / 2,
                    y: -Self.markerSize / 2,
                    width: Self.markerSize,
                    height: Self.markerSize
                )
            ),
            shouldScaleWithZoom: shouldScaleWithZoom,
            hitPadding: hitPadding,
            hitOnly: hitOnly
        )
        return CanvasPath<TestID>(layer: layer)
    }

    func makeStrokedLinePath(
        start: CGPoint,
        end: CGPoint,
        strokeWidth: Double,
        hitPadding: CGFloat,
        hitOnly: Bool = false
    ) -> CanvasPath<TestID> {
        var bezier = BezierPath()
        bezier.move(to: Point(start))
        bezier.addLine(to: Point(end))
        let decorations: [Decoration]
        if strokeWidth > 0 {
            decorations = [
                Decoration.stroke(Stroke(width: strokeWidth, paint: .solid(.black)))
            ]
        } else {
            decorations = []
        }
        let layer = PathLayer<TestID>(
            id: TestID(),
            decorations: decorations,
            bezier: bezier,
            hitPadding: hitPadding,
            hitOnly: hitOnly
        )
        return CanvasPath<TestID>(layer: layer)
    }

    func makeTextCanvas(
        anchor: CGPoint,
        hitPadding: CGFloat
    ) -> CanvasText<TestID> {
        let layer = TextLayer<TestID>(
            id: TestID(),
            transform: BaseKit.Transform(translateX: anchor.x, y: anchor.y),
            position: .zero,
            opacity: 1.0,
            blendMode: .normal,
            isVisible: true,
            decorations: [Decoration.fill(Fill(paint: .solid(.black)))],
            runs: [
                TextRun(
                    text: "A",
                    attributes: [.fontName("Helvetica"), .fontSize(16)]
                )
            ],
            autosize: true,
            width: 200,
            hitPadding: hitPadding
        )
        return CanvasText<TestID>(layer: layer)
    }

    func makeBitmapContext(size: Int) -> CGContext {
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
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        return context
    }

    func isBitmapAllWhite(context: CGContext, size: Int) -> Bool {
        guard let dataPointer = context.data else { return false }
        let total = size * size
        let buffer = dataPointer.bindMemory(to: UInt8.self, capacity: total * 4)
        for i in 0..<total {
            let r = buffer[i * 4]
            let g = buffer[i * 4 + 1]
            let b = buffer[i * 4 + 2]
            if r < 250 || g < 250 || b < 250 {
                return false
            }
        }
        return true
    }
}

private struct TestID: Hashable, Sendable {
    let value: UUID
    init() { self.value = UUID() }
}
