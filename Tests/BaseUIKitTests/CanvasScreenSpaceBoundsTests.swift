import BaseKit
import CoreGraphics
import Foundation
import Testing

@testable import BaseUIKit

/// For layers with `shouldScaleWithZoom: false`, the renderer additionally
/// applies `scaleBy(1/scale)` so the content stays a constant screen-pt size
/// while the doc-space footprint shrinks/grows with zoom. These tests pin
/// that the bounds / intersect / contained / hit-test surface all agree with
/// what the renderer actually draws.
@Suite struct CanvasScreenSpaceBoundsTests {
    // MARK: - PathLayer willDrawRect

    @Test func pathWillDrawRectShrinksWithZoom_whenShouldScaleWithZoomFalse() {
        let bezier = BezierPath(
            rect: Rect(x: -50, y: -50, width: 100, height: 100)
        )
        let layer = PathLayer<TestID>(
            id: TestID(),
            transform: BaseKit.Transform(translateX: 100, y: 100),
            decorations: [Decoration.fill(Fill(paint: .solid(.black)))],
            bezier: bezier,
            shouldScaleWithZoom: false
        )
        let path = CanvasPath<TestID>(layer: layer)

        // At zoom=1, the 100x100 screen-pt rect occupies 100x100 doc-pt.
        drawOnce(path, scale: 1.0)
        let rectAtUnit = path.willDrawRect
        #expect(abs(rectAtUnit.width - 100) <= 1.0, "at 1x got width \(rectAtUnit.width)")
        #expect(abs(rectAtUnit.height - 100) <= 1.0, "at 1x got height \(rectAtUnit.height)")

        // At zoom=2, it should occupy 50x50 doc-pt (still 100x100 screen-pt).
        drawOnce(path, scale: 2.0)
        let rectAtTwoX = path.willDrawRect
        #expect(abs(rectAtTwoX.width - 50) <= 1.0, "at 2x got width \(rectAtTwoX.width)")
        #expect(abs(rectAtTwoX.height - 50) <= 1.0, "at 2x got height \(rectAtTwoX.height)")

        // At zoom=0.5, it should occupy 200x200 doc-pt.
        drawOnce(path, scale: 0.5)
        let rectAtHalfX = path.willDrawRect
        #expect(abs(rectAtHalfX.width - 200) <= 1.0, "at 0.5x got width \(rectAtHalfX.width)")
        #expect(abs(rectAtHalfX.height - 200) <= 1.0, "at 0.5x got height \(rectAtHalfX.height)")
    }

    @Test func pathWillDrawRectUnchanged_whenShouldScaleWithZoomTrue() {
        let bezier = BezierPath(
            rect: Rect(x: -50, y: -50, width: 100, height: 100)
        )
        let layer = PathLayer<TestID>(
            id: TestID(),
            transform: BaseKit.Transform(translateX: 100, y: 100),
            decorations: [Decoration.fill(Fill(paint: .solid(.black)))],
            bezier: bezier,
            shouldScaleWithZoom: true
        )
        let path = CanvasPath<TestID>(layer: layer)

        drawOnce(path, scale: 1.0)
        let r1 = path.willDrawRect
        drawOnce(path, scale: 2.0)
        let r2 = path.willDrawRect
        drawOnce(path, scale: 0.5)
        let r3 = path.willDrawRect
        #expect(abs(r1.width - r2.width) <= 1.0)
        #expect(abs(r1.width - r3.width) <= 1.0)
    }

    // MARK: - intersects + contained, scale-aware

    @Test func pathIntersectsHonorsShouldScaleWithZoomFalse() {
        let bezier = BezierPath(
            rect: Rect(x: -50, y: -50, width: 100, height: 100)
        )
        let layer = PathLayer<TestID>(
            id: TestID(),
            transform: BaseKit.Transform(translateX: 100, y: 100),
            decorations: [Decoration.fill(Fill(paint: .solid(.black)))],
            bezier: bezier,
            shouldScaleWithZoom: false
        )
        let path = CanvasPath<TestID>(layer: layer)

        // At zoom=0.5, visual bounds in doc-space are 200x200 centered at (100, 100):
        // x ∈ [0, 200], y ∈ [0, 200]. A rubber-band at (150, 150)-(190, 190) should
        // intersect the shape (well within the bezier's visual footprint).
        let rubber = CGRect(x: 150, y: 150, width: 40, height: 40)
        #expect(!path.intersectingLayers(rubber, atScale: 0.5, including: { _ in true }).isEmpty)
        // At zoom=2, visual bounds are 50x50 (x ∈ [75, 125]); the same rubber misses.
        #expect(path.intersectingLayers(rubber, atScale: 2.0, including: { _ in true }).isEmpty)
    }

    @Test func pathContainedHonorsShouldScaleWithZoomFalse() {
        let bezier = BezierPath(
            rect: Rect(x: -50, y: -50, width: 100, height: 100)
        )
        let layer = PathLayer<TestID>(
            id: TestID(),
            transform: BaseKit.Transform(translateX: 100, y: 100),
            decorations: [Decoration.fill(Fill(paint: .solid(.black)))],
            bezier: bezier,
            shouldScaleWithZoom: false
        )
        let path = CanvasPath<TestID>(layer: layer)

        // At zoom=2 (visual 50x50, doc bbox x ∈ [75, 125]), a rubber covering
        // (50, 50)-(150, 150) fully contains it.
        let rubber = CGRect(x: 50, y: 50, width: 100, height: 100)
        #expect(!path.containingLayers(rubber, atScale: 2.0, including: { _ in true }).isEmpty)
        // At zoom=0.5 (visual 200x200, doc bbox x ∈ [0, 200]), the same rubber
        // is too small.
        #expect(path.containingLayers(rubber, atScale: 0.5, including: { _ in true }).isEmpty)
    }

    // MARK: - hitTest

    @Test func pathHitTestHonorsShouldScaleWithZoomFalseAtNonUnitZoom() {
        let bezier = BezierPath(
            rect: Rect(x: -50, y: -50, width: 100, height: 100)
        )
        let layer = PathLayer<TestID>(
            id: TestID(),
            transform: BaseKit.Transform(translateX: 100, y: 100),
            decorations: [Decoration.fill(Fill(paint: .solid(.black)))],
            bezier: bezier,
            shouldScaleWithZoom: false
        )
        let path = CanvasPath<TestID>(layer: layer)

        // At zoom=2, visual rect is 50x50 centered on (100, 100). Click at
        // (124, 100) is just inside the right edge (125 - 1); (126, 100) is
        // just past it.
        #expect(path.hitLayer(at: CGPoint(x: 124, y: 100), atScale: 2.0, including: { _ in true }) != nil)
        #expect(path.hitLayer(at: CGPoint(x: 126, y: 100), atScale: 2.0, including: { _ in true }) == nil)

        // At zoom=0.5, visual rect is 200x200 centered on (100, 100). (180, 100)
        // is inside; (210, 100) is outside.
        #expect(path.hitLayer(at: CGPoint(x: 180, y: 100), atScale: 0.5, including: { _ in true }) != nil)
        #expect(path.hitLayer(at: CGPoint(x: 210, y: 100), atScale: 0.5, including: { _ in true }) == nil)
    }

    // MARK: - Stroke.effectiveBounds

    @Test func strokeEffectiveBoundsScalesWhenShouldScaleWithZoomFalse() {
        // Bevel join avoids the miter-limit multiplier so the math here
        // reduces to inset = ceil(width / 2 / scale).
        let stroke = Stroke(
            join: .bevel,
            width: 10,
            paint: .solid(.black),
            shouldScaleWithZoom: false
        )
        let base = CGRect(x: 0, y: 0, width: 100, height: 100)

        // Scale=1: inset 5pt either side.
        let unitBounds = stroke.effectiveBounds(for: base, atScale: 1.0)
        #expect(unitBounds.width == 110)

        // Scale=2: inset by ceil(5 / 2) = 3pt either side.
        let twoBounds = stroke.effectiveBounds(for: base, atScale: 2.0)
        #expect(twoBounds.width == 106, "got width \(twoBounds.width)")

        // Scale=0.5: inset by ceil(5 / 0.5) = 10pt either side.
        let halfBounds = stroke.effectiveBounds(for: base, atScale: 0.5)
        #expect(halfBounds.width == 120)
    }

    @Test func strokeEffectiveBoundsUnchangedWhenShouldScaleWithZoomTrue() {
        let stroke = Stroke(
            join: .bevel,
            width: 10,
            paint: .solid(.black),
            shouldScaleWithZoom: true
        )
        let base = CGRect(x: 0, y: 0, width: 100, height: 100)
        // Insetting is scale-independent when the stroke is doc-space.
        let unit = stroke.effectiveBounds(for: base, atScale: 1.0)
        let two = stroke.effectiveBounds(for: base, atScale: 2.0)
        let half = stroke.effectiveBounds(for: base, atScale: 0.5)
        #expect(unit.width == two.width)
        #expect(unit.width == half.width)
    }

    // MARK: - TextLayer

    @Test func textWillDrawRectShrinksWithZoom_whenShouldScaleWithZoomFalse() {
        let layer = TextLayer<TestID>(
            id: TestID(),
            transform: BaseKit.Transform(translateX: 50, y: 50),
            position: .zero,
            opacity: 1.0,
            blendMode: .normal,
            isVisible: true,
            decorations: [Decoration.fill(Fill(paint: .solid(.black)))],
            runs: [
                TextRun(text: "Hello", attributes: [.fontName("Helvetica"), .fontSize(16)])
            ],
            shouldScaleWithZoom: false,
            autosize: true,
            width: 200
        )
        let text = CanvasText<TestID>(layer: layer)

        drawOnce(text, scale: 1.0)
        let r1 = text.willDrawRect
        drawOnce(text, scale: 2.0)
        let r2 = text.willDrawRect
        // Doc-space footprint halves at 2x zoom (text stays the same screen-pt size).
        #expect(abs(r2.width - r1.width / 2) <= 2.0, "1x width \(r1.width), 2x width \(r2.width)")
        #expect(abs(r2.height - r1.height / 2) <= 2.0)
    }

    @Test func textHitTestHonorsShouldScaleWithZoomFalseAtNonUnitZoom() {
        // Setup: text centered on (100, 100), shouldScaleWithZoom: false.
        let layer = TextLayer<TestID>(
            id: TestID(),
            transform: BaseKit.Transform(translateX: 100, y: 100),
            position: .zero,
            opacity: 1.0,
            blendMode: .normal,
            isVisible: true,
            decorations: [Decoration.fill(Fill(paint: .solid(.black)))],
            runs: [
                TextRun(text: "Hi", attributes: [.fontName("Helvetica"), .fontSize(16)])
            ],
            shouldScaleWithZoom: false,
            autosize: true,
            width: 200
        )
        let text = CanvasText<TestID>(layer: layer)

        // Local-pt bounds (= screen-pt bounds) of "Hi" 16pt.
        guard let localBounds = text.typographicBounds else {
            Issue.record("typographicBounds nil")
            return
        }
        // At zoom=2, doc-space bounds are half local-pt. Hit just inside the
        // right edge of the doc-space-visual extent.
        let docRightAtTwoX = 100 + localBounds.maxX / 2
        #expect(text.hitLayer(at: CGPoint(x: docRightAtTwoX - 1, y: 100), atScale: 2.0, including: { _ in true }) != nil)
        #expect(text.hitLayer(at: CGPoint(x: docRightAtTwoX + 5, y: 100), atScale: 2.0, including: { _ in true }) == nil)
    }

    // MARK: - Integration

    /// At deep zoom-out a screen-pt label that should still be visible must
    /// not be culled. This is the headline symptom the task fixes.
    @Test func screenPtLabelAtDeepZoomOutIsNotCulled() {
        // Local-space label: 100x30 centered on origin.
        let bezier = BezierPath(
            rect: Rect(x: -50, y: -15, width: 100, height: 30)
        )
        let layer = PathLayer<TestID>(
            id: TestID(),
            transform: BaseKit.Transform(translateX: 500, y: 500),
            decorations: [Decoration.fill(Fill(paint: .solid(.black)))],
            bezier: bezier,
            shouldScaleWithZoom: false
        )
        let path = CanvasPath<TestID>(layer: layer)

        // At zoom 0.05, the label's doc-space footprint is 2000x600 centered on
        // (500, 500), i.e., x ∈ [-500, 1500], y ∈ [200, 800].
        // The drawn intersect rect representing a 1000pt-wide doc viewport
        // should be considered overlapping.
        let viewport = CGRect(x: 0, y: 0, width: 1000, height: 1000)
        #expect(!path.intersectingLayers(viewport, atScale: 0.05, including: { _ in true }).isEmpty)

        // Old (buggy) behavior would have computed a static 100x30 footprint
        // far enough off from the viewport that intersects might wrongly
        // pass for the wrong reason — confirm a viewport that *would* miss
        // the static bounds but catches the zoomed visual does intersect.
        let leftViewport = CGRect(x: -400, y: 400, width: 200, height: 200)
        #expect(!path.intersectingLayers(leftViewport, atScale: 0.05, including: { _ in true }).isEmpty)
    }

    /// Regression for screenOffset composition: the previous task's
    /// screenOffset translation in willDrawRect must still apply on top of
    /// the new scale-corrected base bounds.
    @Test func pathScreenOffsetStillCorrect_whenScaledBoundsAlsoApply() {
        let bezier = BezierPath(
            rect: Rect(x: -25, y: -25, width: 50, height: 50)
        )
        let offset = Vector(dx: 20, dy: 0)
        let layer = PathLayer<TestID>(
            id: TestID(),
            transform: BaseKit.Transform(translateX: 200, y: 200),
            screenOffset: offset,
            decorations: [Decoration.fill(Fill(paint: .solid(.black)))],
            bezier: bezier,
            shouldScaleWithZoom: false
        )
        let path = CanvasPath<TestID>(layer: layer)

        drawOnce(path, scale: 2.0)
        let rect = path.willDrawRect
        // Visual: 25x25 doc-pt centered on (200 + 20/2, 200) = (210, 200).
        // x ∈ [197.5, 222.5], y ∈ [187.5, 212.5].
        #expect(abs(rect.midX - 210) <= 1.5, "midX \(rect.midX)")
        #expect(abs(rect.midY - 200) <= 1.5, "midY \(rect.midY)")
        #expect(abs(rect.width - 25) <= 1.5, "width \(rect.width)")
    }
}

private extension CanvasScreenSpaceBoundsTests {
    /// Draw the layer once at the given scale so `lastDrawnAtScale` populates
    /// and the next `willDrawRect` reads it.
    func drawOnce<ID: Hashable & Sendable>(_ object: CanvasPath<ID>, scale: CGFloat) {
        let bitmapSize = 128
        let context = makeBitmapContext(size: bitmapSize)
        context.scaleBy(x: scale, y: scale)
        object.draw(
            CGRect(
                x: -1000, y: -1000,
                width: 2000,
                height: 2000
            ),
            into: context,
            atScale: scale,
            renderingCache: nil
        )
    }

    func drawOnce<ID: Hashable & Sendable>(_ object: CanvasText<ID>, scale: CGFloat) {
        let bitmapSize = 128
        let context = makeBitmapContext(size: bitmapSize)
        context.scaleBy(x: scale, y: scale)
        object.draw(
            CGRect(
                x: -1000, y: -1000,
                width: 2000,
                height: 2000
            ),
            into: context,
            atScale: scale,
            renderingCache: nil
        )
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
}

private struct TestID: Hashable, Sendable {
    let value: UUID
    init() { self.value = UUID() }
}
