import Foundation
import CoreGraphics
import BaseKit
import Synchronization

final class CanvasPath<ID: Hashable & Sendable>: Sendable {
    let id: ID
    var didDrawRect: CGRect {
        memberData.withLock { $0.didDrawRect }
    }
    var layer: Layer<ID> {
        memberData.withLock { $0.layer }
    }
        
    private let memberData: Mutex<MemberData>
    
    init(layer: PathLayer<ID>) {
        self.id = layer.id
        var renderedBezier = layer.bezier
        renderedBezier.transform(layer.transform)
        memberData = Mutex(
            MemberData(
                didDrawRect: .zero,
                layer: .path(layer),
                transform: layer.transform,
                screenOffset: layer.screenOffset,
                opacity: layer.opacity,
                blendMode: layer.blendMode,
                isVisible: layer.isVisible,
                decorations: layer.decorations,
                bezier: layer.bezier,
                shouldScaleWithZoom: layer.shouldScaleWithZoom,
                clipPath: layer.clipPath,
                mask: layer.mask,
                cachedMaskImage: nil,
                filter: layer.filter,
                markers: layer.markers,
                hitPadding: layer.hitPadding,
                hitOnly: layer.hitOnly,
                renderedBezier: renderedBezier,
                lastDrawnAtScale: 1.0
            )
        )
    }
    
}

extension CanvasPath: CanvasObject{
    func updateLayer(_ layer: Layer<ID>) -> Set<CanvasInvalidation> {
        guard case let .path(pathLayer) = layer else {
            return Set()
        }
        return memberData.withLock {
            locked_update(&$0, with: pathLayer)
        }
    }
    
    var willDrawRect: CGRect {
        memberData.withLock {
            locked_willDrawRect(&$0)
        }
    }
        
    func draw(_ rect: CGRect, into context: CGContext, atScale scale: CGFloat, renderingCache: RenderingCache?) {
        memberData.withLock {
            locked_draw(&$0, in: rect, into: context, atScale: scale, renderingCache: renderingCache)
        }
    }
    
    func hitLayer(at location: CGPoint, atScale scale: CGFloat, including predicate: (ID) -> Bool) -> Layer<ID>? {
        guard predicate(id), locked_hits(at: location, atScale: scale) else { return nil }
        return layer
    }

    private func locked_hits(at location: CGPoint, atScale scale: CGFloat) -> Bool {
        memberData.withLock { memberData in
            // `renderedBezier` lives in doc-space without `screenOffset`
            // applied. The on-screen geometry is shifted by
            // `screenOffset / scale` doc-pt — compensate by shifting the test
            // location the other way.
            let adjusted: CGPoint
            if memberData.screenOffset != .zero {
                adjusted = CGPoint(
                    x: location.x - CGFloat(memberData.screenOffset.dx) / scale,
                    y: location.y - CGFloat(memberData.screenOffset.dy) / scale
                )
            } else {
                adjusted = location
            }
            if memberData.shouldScaleWithZoom {
                // Local-pt == doc-pt; renderedBezier is the visual geometry.
                let paddingDoc = memberData.hitPadding / max(scale, 0.0001)
                if locked_hasFill(&memberData) && memberData.renderedBezier.cgPath.contains(adjusted) {
                    return true
                }
                let width = locked_strokeWidth(&memberData)
                let distance = memberData.renderedBezier.distance(to: Point(adjusted))
                return distance <= width + paddingDoc
            } else {
                // Renderer applies `transform * scaleBy(1/scale)`. Bring
                // `adjusted` into local-pt space (where 1 unit = 1 screen-pt)
                // and test against the unscaled `bezier`. In local-pt, the
                // stroke width and hit-padding are both in screen-pt units
                // already.
                let safeScale = max(scale, 0.0001)
                let effective = memberData.transform.toCG
                    .scaledBy(x: 1.0 / safeScale, y: 1.0 / safeScale)
                let local = adjusted.applying(effective.inverted())
                let width = locked_strokeWidth(&memberData)
                if locked_hasFill(&memberData) && memberData.bezier.cgPath.contains(local) {
                    return true
                }
                let distance = memberData.bezier.distance(to: Point(local))
                return distance <= width + memberData.hitPadding
            }
        }
    }

    func intersectingLayers(_ rect: CGRect, atScale scale: CGFloat, including predicate: (ID) -> Bool) -> [Layer<ID>] {
        guard predicate(id) else { return [] }
        let hits = memberData.withLock {
            locked_visualCgPath(&$0, atScale: scale).intersects(CGPath(rect: rect, transform: nil))
        }
        return hits ? [layer] : []
    }

    func containingLayers(_ rect: CGRect, atScale scale: CGFloat, including predicate: (ID) -> Bool) -> [Layer<ID>] {
        guard predicate(id) else { return [] }
        let inside = memberData.withLock {
            rect.contains(locked_visualCgPath(&$0, atScale: scale).boundingBoxOfPath)
        }
        return inside ? [layer] : []
    }

    var structurePath: BezierPath {
        memberData.withLock {
            $0.renderedBezier
        }
    }

    var typographicBounds: CGRect? { nil }

    var outlinePath: BezierPath { structurePath }

    func textIndex(at location: CGPoint) -> TextPosition? {
        nil
    }

    func textRects(for range: TextRange) -> [CGRect]? {
        nil
    }

    func navigateText(_ navigation: TextNavigation, from position: TextPosition) -> TextPosition? {
        nil
    }

    func caretRect(at position: TextPosition) -> CGRect? {
        nil
    }

    var transform: Transform {
        memberData.withLock { $0.transform }
    }
}

private extension CanvasPath {
    struct MemberData {
        var didDrawRect: CGRect
        var layer: Layer<ID>
        var transform: Transform
        var screenOffset: Vector
        var opacity: Double
        var blendMode: BlendMode
        var isVisible: Bool
        var decorations: [Decoration]
        var bezier: BezierPath
        var shouldScaleWithZoom: Bool
        var clipPath: ClipPath?
        var mask: MaskLayer?
        var cachedMaskImage: CGImage?
        var filter: FilterLayer?
        var markers: MarkerLayer?
        var hitPadding: CGFloat
        var hitOnly: Bool
        var renderedBezier: BezierPath
        // The scale we most recently drew at. Used by `locked_willDrawRect`
        // to convert `screenOffset` from screen-pt to doc-pt without
        // threading a `scale` argument through every call site that asks
        // for the rect. Default `1.0` is fine for the first draw — the
        // first invalidation has no prior state to clear and a wrong rect
        // here just means slightly under-aggressive culling on that one
        // frame.
        var lastDrawnAtScale: CGFloat
    }
    
    func locked_structureBounds(_ memberData: inout MemberData) -> CGRect {
        memberData.renderedBezier.cgPath.boundingBoxOfPath
    }

    func locked_willDrawRect(_ memberData: inout MemberData) -> CGRect {
        // Hit-only layers never paint, so they contribute nothing to
        // invalidation regions.
        guard !memberData.hitOnly else { return .zero }
        let scale = max(memberData.lastDrawnAtScale, 0.0001)
        var rect = locked_quickGlobalEffectiveBounds(&memberData, atScale: scale)
        if memberData.screenOffset != .zero {
            rect = rect.offsetBy(
                dx: CGFloat(memberData.screenOffset.dx) / scale,
                dy: CGFloat(memberData.screenOffset.dy) / scale
            )
        }
        return rect
    }

    func locked_draw(_ memberData: inout MemberData, in rect: CGRect, into context: CGContext, atScale scale: CGFloat, renderingCache: RenderingCache?) {
        memberData.lastDrawnAtScale = scale
        guard !memberData.hitOnly else {
            memberData.didDrawRect = .zero
            return
        }
        // Compute willDrawRect at the actual scale (not lastDrawnAtScale)
        // so the cull/didDrawRect agree with the geometry we're about to
        // paint, even on the first frame at a fresh zoom.
        var willDraw = locked_quickGlobalEffectiveBounds(&memberData, atScale: scale)
        if memberData.screenOffset != .zero {
            let safeScale = max(scale, 0.0001)
            willDraw = willDraw.offsetBy(
                dx: CGFloat(memberData.screenOffset.dx) / safeScale,
                dy: CGFloat(memberData.screenOffset.dy) / safeScale
            )
        }
        guard willDraw.intersects(rect) else {
            return
        }

        memberData.didDrawRect = willDraw

        guard memberData.isVisible else {
            return
        }

        if memberData.mask != nil, memberData.cachedMaskImage == nil {
            memberData.cachedMaskImage = memberData.mask?.renderToMaskImage(scale: scale)
        }

        let effects = LayerEffects(
            opacity: memberData.opacity,
            blendMode: memberData.blendMode,
            transform: memberData.transform,
            clipPath: memberData.clipPath,
            mask: memberData.mask,
            maskImage: memberData.cachedMaskImage,
            filter: memberData.filter
        )
        effects.draw(in: context, atScale: scale, renderingCache: renderingCache) { target in
            locked_drawSelf(&memberData, in: rect, into: target, atScale: scale, renderingCache: renderingCache)
        }
    }

    func locked_drawSelf(_ memberData: inout MemberData, in rect: CGRect, into context: CGContext, atScale scale: CGFloat, renderingCache: RenderingCache?) {
        if !memberData.shouldScaleWithZoom {
            context.scaleBy(x: 1.0 / scale, y: 1.0 / scale)
        }
        if memberData.screenOffset != .zero {
            // After the 1/scale above, local units == screen-pt and the
            // offset can be applied directly. Without the inversion local
            // units are doc-pt, so divide by scale to land at the same
            // device-pt displacement.
            let factor: CGFloat = memberData.shouldScaleWithZoom ? (1.0 / scale) : 1.0
            context.translateBy(
                x: CGFloat(memberData.screenOffset.dx) * factor,
                y: CGFloat(memberData.screenOffset.dy) * factor
            )
        }
        let bezier = memberData.bezier
        for decoration in memberData.decorations {
            bezier.set(in: context)
            decoration.render(into: context, atScale: scale, renderingCache: renderingCache)
        }
        if let markers = memberData.markers {
            for placement in markers.placements {
                context.saveGState()
                context.translateBy(
                    x: CGFloat(placement.position.x),
                    y: CGFloat(placement.position.y)
                )
                context.rotate(by: CGFloat(placement.angle))
                context.concatenate(placement.markerTransform.toCG)
                for shape in placement.shapes {
                    shape.render(into: context, atScale: scale, renderingCache: renderingCache)
                }
                context.restoreGState()
            }
        }
    }

    func locked_hasFill(_ memberData: inout MemberData) -> Bool {
        memberData.decorations.contains {
            if case .fill = $0 {
                return true
            } else {
                return false
            }
        }
    }
    
    func locked_strokeWidth(_ memberData: inout MemberData) -> CGFloat {
        memberData.decorations.map {
            if case let .stroke(stroke) = $0 {
                return stroke.width
            } else {
                return 0
            }
        }.max() ?? 0
    }
        
    func locked_update(
        _ memberData: inout MemberData,
        with layer: PathLayer<ID>
    ) -> Set<CanvasInvalidation> {
        var didChange = false
        var needsRenderedBezierUpdate = false
        memberData.layer = .path(layer)
        if memberData.transform != layer.transform {
            memberData.transform = layer.transform
            needsRenderedBezierUpdate = true
            didChange = true
        }
        if memberData.screenOffset != layer.screenOffset {
            memberData.screenOffset = layer.screenOffset
            didChange = true
        }
        if memberData.opacity != layer.opacity {
            memberData.opacity = layer.opacity
            didChange = true
        }
        if memberData.blendMode != layer.blendMode {
            memberData.blendMode = layer.blendMode
            didChange = true
        }
        if memberData.isVisible != layer.isVisible {
            memberData.isVisible = layer.isVisible
            didChange = true
        }
        // TODO: equivalent, not equal
        if memberData.decorations != layer.decorations {
            memberData.decorations = layer.decorations
            didChange = true
        }
        if memberData.bezier != layer.bezier {
            memberData.bezier = layer.bezier
            needsRenderedBezierUpdate = true
            didChange = true
        }
        if needsRenderedBezierUpdate {
            memberData.renderedBezier = memberData.bezier
            memberData.renderedBezier.transform(memberData.transform)
        }
        if memberData.shouldScaleWithZoom != layer.shouldScaleWithZoom {
            memberData.shouldScaleWithZoom = layer.shouldScaleWithZoom
            didChange = true
        }
        if memberData.clipPath != layer.clipPath {
            memberData.clipPath = layer.clipPath
            didChange = true
        }
        if memberData.mask != layer.mask {
            memberData.mask = layer.mask
            memberData.cachedMaskImage = nil
            didChange = true
        }
        if memberData.filter != layer.filter {
            memberData.filter = layer.filter
            didChange = true
        }
        if memberData.markers != layer.markers {
            memberData.markers = layer.markers
            didChange = true
        }
        if memberData.hitPadding != layer.hitPadding {
            memberData.hitPadding = layer.hitPadding
            // Pure hit-test change, no invalidate needed, but mark didChange
            // so downstream observers see the new layer value.
            didChange = true
        }
        if memberData.hitOnly != layer.hitOnly {
            memberData.hitOnly = layer.hitOnly
            didChange = true
        }
        if didChange {
            return Set([.invalidateRect(memberData.didDrawRect), .invalidateRect(locked_willDrawRect(&memberData))])
        } else {
            return Set()
        }
    }
    
    func locked_visualCgPath(_ memberData: inout MemberData, atScale scale: CGFloat) -> CGPath {
        if memberData.shouldScaleWithZoom {
            return memberData.renderedBezier.cgPath
        }
        // Renderer applies `transform * scaleBy(1/scale)` to the local
        // bezier. Build that effective transform here and copy the path
        // through it; callers use the result for shape-precise rubber-band
        // intersect / contained tests.
        let safeScale = max(scale, 0.0001)
        var effective = memberData.transform.toCG
            .scaledBy(x: 1.0 / safeScale, y: 1.0 / safeScale)
        return memberData.bezier.cgPath.copy(using: &effective) ?? memberData.bezier.cgPath
    }

    func locked_quickGlobalEffectiveBounds(_ memberData: inout MemberData, atScale scale: CGFloat) -> CGRect {
        // Visual bounds of the bezier in doc-space. When
        // `shouldScaleWithZoom: false`, the renderer additionally applies
        // `scaleBy(1/scale)` around the transform origin, shrinking the
        // doc-space footprint accordingly.
        let safeScale = max(scale, 0.0001)
        let bezierDocBounds: CGRect
        if memberData.shouldScaleWithZoom {
            bezierDocBounds = memberData.renderedBezier.cgQuickBounds
        } else {
            let effective = memberData.transform.toCG
                .scaledBy(x: 1.0 / safeScale, y: 1.0 / safeScale)
            bezierDocBounds = memberData.bezier.cgQuickBounds.applying(effective)
        }
        var bounds = memberData.decorations.effectiveBounds(for: bezierDocBounds, atScale: safeScale)
        if let markers = memberData.markers {
            for placement in markers.placements {
                for shape in placement.shapes {
                    let shapeBounds = shape.path.quickBounds ?? .zero
                    let markerSize = max(shapeBounds.width, shapeBounds.height)
                    let expand = CGFloat(markerSize)
                    let placementRect = CGRect(
                        x: CGFloat(placement.position.x) - expand,
                        y: CGFloat(placement.position.y) - expand,
                        width: expand * 2,
                        height: expand * 2
                    )
                    bounds = bounds.union(placementRect)
                }
            }
        }
        return bounds
    }
}
