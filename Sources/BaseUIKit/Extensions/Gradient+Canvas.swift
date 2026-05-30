import Foundation
import CoreGraphics
import BaseKit

public extension Gradient {
    func fill(_ context: CGContext, using fillRule: CGPathFillRule) {
        guard !stops.isEmpty else { return }

        context.saveGState()
        context.beginTransparencyLayer(auxiliaryInfo: nil)

        context.clip(using: fillRule)

        if let boundingBox {
            context.translateBy(x: boundingBox.minX, y: boundingBox.minY)
            context.scaleBy(x: boundingBox.width, y: boundingBox.height)
        }

        if let gradientTransform {
            context.concatenate(gradientTransform.toCG)
        }

        switch kind {
        case .linear:
            drawLinear(in: context)
        case .radial:
            drawRadial(in: context)
        }
        context.endTransparencyLayer()
        context.restoreGState()
    }

    func stroke(_ context: CGContext) {
        context.saveGState()

        context.replacePathWithStrokedPath()
        fill(context, using: .evenOdd)

        context.restoreGState()
    }
}

private extension Gradient {
    // Pathological cases (tiny gradient extent vs. huge clip path) would
    // otherwise synthesize thousands of vanishingly thin tiles. Cap at a
    // value that's well past what's visible at any reasonable zoom.
    static let maxTileCount = 256

    func drawLinear(in context: CGContext) {
        let startCG = start.toCG
        let endCG = end.toCG

        switch spreadMethod {
        case .pad:
            guard let cg = makeCGGradient(from: stops) else { return }
            context.drawLinearGradient(
                cg, start: startCG, end: endCG,
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )

        case .reflect, .repeat:
            let dx = endCG.x - startCG.x
            let dy = endCG.y - startCG.y
            let lenSq = dx * dx + dy * dy
            guard lenSq > 0 else { return }

            guard let (tileStart, tileEnd) = linearTileRange(
                startCG: startCG, dx: dx, dy: dy, lenSq: lenSq,
                clipBox: context.boundingBoxOfClipPath
            ) else {
                // Fall back to pad if we can't bound the area.
                guard let cg = makeCGGradient(from: stops) else { return }
                context.drawLinearGradient(
                    cg, start: startCG, end: endCG,
                    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                )
                return
            }

            let expanded = expandedStops(
                tileStart: tileStart, tileEnd: tileEnd,
                reflect: spreadMethod == .reflect
            )
            guard let cg = makeCGGradient(from: expanded) else { return }

            let extStart = CGPoint(
                x: startCG.x + dx * CGFloat(tileStart),
                y: startCG.y + dy * CGFloat(tileStart)
            )
            let extEnd = CGPoint(
                x: startCG.x + dx * CGFloat(tileEnd),
                y: startCG.y + dy * CGFloat(tileEnd)
            )
            context.drawLinearGradient(cg, start: extStart, end: extEnd, options: [])
        }
    }

    func drawRadial(in context: CGContext) {
        let focalCG = (focalPoint ?? start).toCG
        let centerCG = start.toCG
        let endR = start.distance(to: end)
        guard endR > 0 else { return }

        switch spreadMethod {
        case .pad:
            guard let cg = makeCGGradient(from: stops) else { return }
            context.drawRadialGradient(
                cg,
                startCenter: focalCG, startRadius: 0,
                endCenter: centerCG, endRadius: endR,
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )

        case .reflect, .repeat:
            guard let tileCount = radialTileCount(
                focalCG: focalCG, endR: endR,
                clipBox: context.boundingBoxOfClipPath
            ) else {
                guard let cg = makeCGGradient(from: stops) else { return }
                context.drawRadialGradient(
                    cg,
                    startCenter: focalCG, startRadius: 0,
                    endCenter: centerCG, endRadius: endR,
                    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                )
                return
            }

            let expanded = expandedStops(
                tileStart: 0, tileEnd: tileCount,
                reflect: spreadMethod == .reflect
            )
            guard let cg = makeCGGradient(from: expanded) else { return }

            context.drawRadialGradient(
                cg,
                startCenter: focalCG, startRadius: 0,
                endCenter: centerCG, endRadius: endR * CGFloat(tileCount),
                options: []
            )
        }
    }

    func linearTileRange(
        startCG: CGPoint,
        dx: CGFloat, dy: CGFloat, lenSq: CGFloat,
        clipBox: CGRect
    ) -> (Int, Int)? {
        guard clipBox.isFinite else { return nil }

        let corners: [CGPoint] = [
            CGPoint(x: clipBox.minX, y: clipBox.minY),
            CGPoint(x: clipBox.maxX, y: clipBox.minY),
            CGPoint(x: clipBox.minX, y: clipBox.maxY),
            CGPoint(x: clipBox.maxX, y: clipBox.maxY),
        ]
        let us = corners.map { p -> CGFloat in
            ((p.x - startCG.x) * dx + (p.y - startCG.y) * dy) / lenSq
        }
        guard let uMin = us.min(), let uMax = us.max() else { return nil }

        var tileStart = Int(floor(uMin))
        var tileEnd = Int(ceil(uMax))
        if tileEnd <= tileStart { tileEnd = tileStart + 1 }
        if tileEnd - tileStart > Gradient.maxTileCount {
            let mid = (tileStart + tileEnd) / 2
            tileStart = mid - Gradient.maxTileCount / 2
            tileEnd = tileStart + Gradient.maxTileCount
        }
        return (tileStart, tileEnd)
    }

    func radialTileCount(focalCG: CGPoint, endR: CGFloat, clipBox: CGRect) -> Int? {
        guard clipBox.isFinite else { return nil }

        let corners: [CGPoint] = [
            CGPoint(x: clipBox.minX, y: clipBox.minY),
            CGPoint(x: clipBox.maxX, y: clipBox.minY),
            CGPoint(x: clipBox.minX, y: clipBox.maxY),
            CGPoint(x: clipBox.maxX, y: clipBox.maxY),
        ]
        let maxDist = corners.map { hypot($0.x - focalCG.x, $0.y - focalCG.y) }.max() ?? endR
        return max(1, min(Gradient.maxTileCount, Int(ceil(maxDist / endR))))
    }

    func makeCGGradient(from stops: [Stop]) -> CGGradient? {
        let colors = stops.map { $0.color.toCG }
        var locations = stops.map { CGFloat($0.offset) }
        // Interpolate in sRGB to match WebKit / SVG 1.1 default
        // (color-interpolation="sRGB"). Passing nil here gives device-RGB
        // linear-light interpolation, which produces noticeably brighter
        // midtones across red↔blue / yellow↔green transitions.
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        return CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)
    }

    // Build a stops list covering `[tileStart, tileEnd)` tiles of the
    // original gradient, with offsets remapped into [0, 1] so a single
    // CGGradient draws between the extended endpoints.
    //
    // .reflect: alternating tiles run in reverse so consecutive boundary
    //   colors match — the resulting gradient is C0-continuous across tiles.
    // .repeat: every tile runs forward; the last color of one tile and the
    //   first color of the next coincide at the same offset, producing a
    //   hard transition.
    func expandedStops(tileStart: Int, tileEnd: Int, reflect: Bool) -> [Stop] {
        let tileCount = tileEnd - tileStart
        guard tileCount >= 1, !stops.isEmpty else { return stops }

        var result: [Stop] = []
        result.reserveCapacity(tileCount * stops.count)

        for tile in tileStart..<tileEnd {
            // Swift's `%` preserves the dividend's sign, so this catches
            // both positive and negative odd tile indices correctly.
            let isReversed = reflect && (tile % 2 != 0)
            let tileStops: [Stop] = isReversed
                ? stops.reversed().map { Stop(offset: 1.0 - $0.offset, color: $0.color) }
                : stops
            for stop in tileStops {
                let global = (Double(tile - tileStart) + stop.offset) / Double(tileCount)
                result.append(Stop(offset: global, color: stop.color))
            }
        }
        return result
    }
}

private extension CGRect {
    var isFinite: Bool {
        !isInfinite && !isNull && !isEmpty
    }
}
