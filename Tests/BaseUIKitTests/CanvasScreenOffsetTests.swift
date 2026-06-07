import BaseKit
import CoreGraphics
import Foundation
import Testing

@testable import BaseUIKit

/// `screenOffset` on `PathLayer` and `TextLayer` shifts the rendered content
/// by a constant device-pt vector — independent of the canvas zoom and
/// independent of `shouldScaleWithZoom`. These tests pin that contract by
/// measuring the center of mass of a small filled marker at different zooms
/// and asserting the offset matches device-pt, not doc-pt.
@Suite struct CanvasScreenOffsetTests {
    @Test func pathScreenOffsetIsConstantDevicePtAcrossZoom_screenSpace() {
        for scale in [1.0, 2.0, 3.0] {
            let baseline = pathMarkerCenterOfMass(
                scale: CGFloat(scale),
                screenOffset: .zero,
                shouldScaleWithZoom: false
            )
            let shifted = pathMarkerCenterOfMass(
                scale: CGFloat(scale),
                screenOffset: Vector(dx: 10, dy: 0),
                shouldScaleWithZoom: false
            )
            #expect(
                abs((shifted.x - baseline.x) - 10) <= 1.0,
                "scale \(scale): expected ~10 device-pt x shift, got \(shifted.x - baseline.x)"
            )
            #expect(
                abs(shifted.y - baseline.y) <= 1.0,
                "scale \(scale): y should be unchanged"
            )
        }
    }

    @Test func pathScreenOffsetIsConstantDevicePtAcrossZoom_docSpace() {
        for scale in [1.0, 2.0, 3.0] {
            let baseline = pathMarkerCenterOfMass(
                scale: CGFloat(scale),
                screenOffset: .zero,
                shouldScaleWithZoom: true
            )
            let shifted = pathMarkerCenterOfMass(
                scale: CGFloat(scale),
                screenOffset: Vector(dx: 10, dy: 0),
                shouldScaleWithZoom: true
            )
            #expect(
                abs((shifted.x - baseline.x) - 10) <= 1.0,
                "scale \(scale): expected ~10 device-pt x shift, got \(shifted.x - baseline.x)"
            )
            #expect(
                abs(shifted.y - baseline.y) <= 1.0,
                "scale \(scale): y should be unchanged"
            )
        }
    }

    /// At zoom 1, `screenOffset(10,0)` should be visually indistinguishable
    /// from baking the offset into the `transform` translate.
    @Test func pathScreenOffsetEqualsTransformTranslateAtUnitZoom() {
        let viaScreenOffset = pathMarkerCenterOfMass(
            scale: 1.0,
            screenOffset: Vector(dx: 10, dy: 0),
            shouldScaleWithZoom: false
        )
        let viaTransform = pathMarkerCenterOfMassUsingTransform(
            scale: 1.0,
            additionalTranslate: CGPoint(x: 10, y: 0),
            shouldScaleWithZoom: false
        )
        #expect(abs(viaScreenOffset.x - viaTransform.x) <= 1.0)
        #expect(abs(viaScreenOffset.y - viaTransform.y) <= 1.0)
    }

    /// At zoom 2, `screenOffset(10,0)` should differ from a `translate(10,0)`
    /// baked into the transform: the latter scales to 20 device-pt, the
    /// former stays at 10 device-pt.
    @Test func pathScreenOffsetDivergesFromTransformTranslateAtZoom() {
        let viaScreenOffset = pathMarkerCenterOfMass(
            scale: 2.0,
            screenOffset: Vector(dx: 10, dy: 0),
            shouldScaleWithZoom: true
        )
        let viaTransform = pathMarkerCenterOfMassUsingTransform(
            scale: 2.0,
            additionalTranslate: CGPoint(x: 10, y: 0),
            shouldScaleWithZoom: true
        )
        let delta = viaTransform.x - viaScreenOffset.x
        #expect(
            abs(delta - 10) <= 1.0,
            "expected transform-translate to be ~10 device-pt further right than screenOffset at 2x zoom, got delta=\(delta)"
        )
    }

    @Test func pathHitTestSucceedsAtVisualLocationAcrossZoom() {
        let offset = Vector(dx: 10, dy: 0)
        for scale in [0.5, 1.0, 2.0, 3.0] {
            let path = makePathCanvasObject(
                anchor: Self.anchor,
                screenOffset: offset,
                shouldScaleWithZoom: false
            )
            // The fill rect sits at doc anchor + screenOffset/scale.
            let visualX = Self.anchor.x + CGFloat(offset.dx) / CGFloat(scale)
            #expect(
                path.hitLayer(at: CGPoint(x: visualX, y: Self.anchor.y), atScale: CGFloat(scale), including: { _ in true }) != nil,
                "scale \(scale): visual location should hit"
            )
            #expect(
                path.hitLayer(at: Self.anchor, atScale: CGFloat(scale), including: { _ in true }) == nil,
                "scale \(scale): the raw anchor should miss (geometry has shifted off it)"
            )
        }
    }

    @Test func textHitTestSucceedsAtVisualLocationAcrossZoom() {
        let offset = Vector(dx: 10, dy: 0)
        for scale in [1.0, 2.0] {
            let text = makeTextCanvasObject(
                anchor: Self.anchor,
                screenOffset: offset,
                shouldScaleWithZoom: false
            )
            let visualX = Self.anchor.x + CGFloat(offset.dx) / CGFloat(scale)
            #expect(
                text.hitLayer(at: CGPoint(x: visualX, y: Self.anchor.y), atScale: CGFloat(scale), including: { _ in true }) != nil,
                "scale \(scale): visual location should hit"
            )
        }
    }

    /// After drawing at a non-unit scale, `willDrawRect` must cover the
    /// shifted geometry. Otherwise the canvas invalidates the wrong rect on
    /// the next update and leaves stale pixels behind.
    @Test func pathWillDrawRectIncludesShiftedGeometryAfterDraw() {
        for scale in [0.5, 1.0, 2.0] {
            let offset = Vector(dx: 12, dy: -8)
            let path = makePathCanvasObject(
                anchor: Self.anchor,
                screenOffset: offset,
                shouldScaleWithZoom: false
            )
            // Draw once to populate `lastDrawnAtScale`.
            let bitmapSize = 128
            let context = makeBitmapContext(size: bitmapSize)
            context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
            path.draw(
                CGRect(
                    x: 0, y: 0,
                    width: Double(bitmapSize) / scale,
                    height: Double(bitmapSize) / scale
                ),
                into: context,
                atScale: CGFloat(scale),
                renderingCache: nil
            )

            let visualX = Self.anchor.x + CGFloat(offset.dx) / CGFloat(scale)
            let visualY = Self.anchor.y + CGFloat(offset.dy) / CGFloat(scale)
            #expect(
                path.willDrawRect.contains(CGPoint(x: visualX, y: visualY)),
                "scale \(scale): willDrawRect should contain the shifted geometry; got \(path.willDrawRect)"
            )
        }
    }

    @Test func textScreenOffsetIsConstantDevicePtAcrossZoom_screenSpace() {
        for scale in [1.0, 2.0, 3.0] {
            let baseline = textCenterOfMass(
                scale: CGFloat(scale),
                screenOffset: .zero,
                shouldScaleWithZoom: false
            )
            let shifted = textCenterOfMass(
                scale: CGFloat(scale),
                screenOffset: Vector(dx: 10, dy: 0),
                shouldScaleWithZoom: false
            )
            #expect(
                abs((shifted.x - baseline.x) - 10) <= 1.5,
                "scale \(scale): expected ~10 device-pt x shift, got \(shifted.x - baseline.x)"
            )
            #expect(
                abs(shifted.y - baseline.y) <= 1.5,
                "scale \(scale): y should be unchanged"
            )
        }
    }
}

private extension CanvasScreenOffsetTests {
    static let anchor = CGPoint(x: 20, y: 20)
    static let markerSize: CGFloat = 4

    func makePathCanvasObject(
        anchor: CGPoint,
        screenOffset: Vector,
        shouldScaleWithZoom: Bool
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
            shouldScaleWithZoom: shouldScaleWithZoom
        )
        return CanvasPath<TestID>(layer: layer)
    }

    func makeTextCanvasObject(
        anchor: CGPoint,
        screenOffset: Vector,
        shouldScaleWithZoom: Bool
    ) -> CanvasText<TestID> {
        let layer = TextLayer<TestID>(
            id: TestID(),
            transform: BaseKit.Transform(translateX: anchor.x, y: anchor.y),
            position: .zero,
            screenOffset: screenOffset,
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
            shouldScaleWithZoom: shouldScaleWithZoom,
            autosize: true,
            width: 200
        )
        return CanvasText<TestID>(layer: layer)
    }

    func pathMarkerCenterOfMass(
        scale: CGFloat,
        screenOffset: Vector,
        shouldScaleWithZoom: Bool
    ) -> CGPoint {
        let bitmapSize = 128
        let context = makeBitmapContext(size: bitmapSize)
        context.scaleBy(x: scale, y: scale)

        let layer = PathLayer<TestID>(
            id: TestID(),
            transform: BaseKit.Transform(
                translateX: Self.anchor.x,
                y: Self.anchor.y
            ),
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
            shouldScaleWithZoom: shouldScaleWithZoom
        )
        CanvasPath<TestID>(layer: layer).draw(
            CGRect(
                x: 0, y: 0,
                width: Double(bitmapSize) / scale,
                height: Double(bitmapSize) / scale
            ),
            into: context,
            atScale: scale,
            renderingCache: nil
        )
        return centerOfMass(context: context, size: bitmapSize)
    }

    func pathMarkerCenterOfMassUsingTransform(
        scale: CGFloat,
        additionalTranslate: CGPoint,
        shouldScaleWithZoom: Bool
    ) -> CGPoint {
        let bitmapSize = 128
        let context = makeBitmapContext(size: bitmapSize)
        context.scaleBy(x: scale, y: scale)

        let layer = PathLayer<TestID>(
            id: TestID(),
            transform: BaseKit.Transform(
                translateX: Self.anchor.x + additionalTranslate.x,
                y: Self.anchor.y + additionalTranslate.y
            ),
            decorations: [Decoration.fill(Fill(paint: .solid(.black)))],
            bezier: BezierPath(
                rect: Rect(
                    x: -Self.markerSize / 2,
                    y: -Self.markerSize / 2,
                    width: Self.markerSize,
                    height: Self.markerSize
                )
            ),
            shouldScaleWithZoom: shouldScaleWithZoom
        )
        CanvasPath<TestID>(layer: layer).draw(
            CGRect(
                x: 0, y: 0,
                width: Double(bitmapSize) / scale,
                height: Double(bitmapSize) / scale
            ),
            into: context,
            atScale: scale,
            renderingCache: nil
        )
        return centerOfMass(context: context, size: bitmapSize)
    }

    func textCenterOfMass(
        scale: CGFloat,
        screenOffset: Vector,
        shouldScaleWithZoom: Bool
    ) -> CGPoint {
        let bitmapSize = 128
        let context = makeBitmapContext(size: bitmapSize)
        context.scaleBy(x: scale, y: scale)

        let layer = TextLayer<TestID>(
            id: TestID(),
            transform: BaseKit.Transform(
                translateX: Self.anchor.x,
                y: Self.anchor.y
            ),
            position: .zero,
            screenOffset: screenOffset,
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
            shouldScaleWithZoom: shouldScaleWithZoom,
            autosize: true,
            width: 200
        )
        CanvasText<TestID>(layer: layer).draw(
            CGRect(
                x: 0, y: 0,
                width: Double(bitmapSize) / scale,
                height: Double(bitmapSize) / scale
            ),
            into: context,
            atScale: scale,
            renderingCache: nil
        )
        return centerOfMass(context: context, size: bitmapSize)
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
    init() { self.value = UUID() }
}
