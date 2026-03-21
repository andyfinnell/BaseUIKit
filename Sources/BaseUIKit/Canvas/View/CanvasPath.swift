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
                renderedBezier: renderedBezier
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
    
    func hitTest(_ location: CGPoint) -> Bool {
        memberData.withLock { memberData in
            if locked_hasFill(&memberData) && memberData.renderedBezier.cgPath.contains(location) {
                return true
            } else {
                let width = locked_strokeWidth(&memberData)
                let distance = memberData.renderedBezier.distance(to: Point(location))
                return distance <= width
            }
        }
    }
    
    func intersects(_ rect: CGRect) -> Bool {
        memberData.withLock {
            $0.renderedBezier.cgPath.intersects(CGPath(rect: rect, transform: nil))
        }
    }
    
    func contained(by rect: CGRect) -> Bool {
        memberData.withLock {
            rect.contains($0.renderedBezier.cgPath.boundingBoxOfPath)
        }
    }

    var structurePath: BezierPath {
        memberData.withLock {
            $0.renderedBezier
        }
    }

    var typographicBounds: CGRect? { nil }

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
}

private extension CanvasPath {
    struct MemberData {
        var didDrawRect: CGRect
        var layer: Layer<ID>
        var transform: Transform
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
        var renderedBezier: BezierPath
    }
    
    func locked_structureBounds(_ memberData: inout MemberData) -> CGRect {
        memberData.renderedBezier.cgPath.boundingBoxOfPath
    }

    func locked_willDrawRect(_ memberData: inout MemberData) -> CGRect {
        locked_quickGlobalEffectiveBounds(&memberData)
    }

    func locked_draw(_ memberData: inout MemberData, in rect: CGRect, into context: CGContext, atScale scale: CGFloat, renderingCache: RenderingCache?) {
        guard locked_willDrawRect(&memberData).intersects(rect) else {
            return
        }
        
        memberData.didDrawRect = locked_willDrawRect(&memberData)

        guard memberData.isVisible else {
            return
        }

        context.saveGState()

        let needsTransparencyLayer = memberData.opacity < 1.0 || memberData.blendMode != .normal
        if needsTransparencyLayer {
            context.setAlpha(memberData.opacity)
            context.setBlendMode(memberData.blendMode.toCG)
            context.beginTransparencyLayer(auxiliaryInfo: nil)
        }

        let affineTransform = memberData.transform.toCG
        context.concatenate(affineTransform)

        if let clipPath = memberData.clipPath {
            clipPath.path.set(in: context)
            context.clip(using: clipPath.fillRule.toCG)
        }

        if let mask = memberData.mask {
            if memberData.cachedMaskImage == nil {
                memberData.cachedMaskImage = mask.renderToMaskImage(scale: scale)
            }
            if let maskImage = memberData.cachedMaskImage {
                context.clip(to: mask.bounds.toCG, mask: maskImage)
            }
        }

        if let filter = memberData.filter {
            filter.drawFiltered(into: context, scale: scale, renderingCache: renderingCache) { targetContext in
                locked_drawSelf(&memberData, in: rect, into: targetContext, atScale: scale, renderingCache: renderingCache)
            }
        } else {
            locked_drawSelf(&memberData, in: rect, into: context, atScale: scale, renderingCache: renderingCache)
        }

        if needsTransparencyLayer {
            context.endTransparencyLayer()
        }
        context.restoreGState()
    }

    func locked_drawSelf(_ memberData: inout MemberData, in rect: CGRect, into context: CGContext, atScale scale: CGFloat, renderingCache: RenderingCache?) {
        if !memberData.shouldScaleWithZoom {
            context.scaleBy(x: 1.0 / scale, y: 1.0 / scale)
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
        if didChange {
            return Set([.invalidateRect(memberData.didDrawRect), .invalidateRect(locked_willDrawRect(&memberData))])
        } else {
            return Set()
        }
    }
    
    func locked_quickGlobalEffectiveBounds(_ memberData: inout MemberData) -> CGRect {
        var bounds = memberData.decorations.effectiveBounds(for: memberData.renderedBezier.cgQuickBounds)
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
