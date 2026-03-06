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
        
    func draw(_ rect: CGRect, into context: CGContext, atScale scale: CGFloat) {
        memberData.withLock {
            locked_draw(&$0, in: rect, into: context, atScale: scale)
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
        var renderedBezier: BezierPath
    }
    
    func locked_structureBounds(_ memberData: inout MemberData) -> CGRect {
        memberData.renderedBezier.cgPath.boundingBoxOfPath
    }

    func locked_willDrawRect(_ memberData: inout MemberData) -> CGRect {
        locked_quickGlobalEffectiveBounds(&memberData)
    }

    func locked_draw(_ memberData: inout MemberData, in rect: CGRect, into context: CGContext, atScale scale: CGFloat) {
        guard locked_willDrawRect(&memberData).intersects(rect) else {
            return
        }
        
        memberData.didDrawRect = locked_willDrawRect(&memberData)

        guard memberData.isVisible else {
            return
        }

        context.saveGState()
        
        context.setAlpha(memberData.opacity)
        context.setBlendMode(memberData.blendMode.toCG)
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        
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
            filter.drawFiltered(into: context, scale: scale) { targetContext in
                locked_drawSelf(&memberData, in: rect, into: targetContext, atScale: scale)
            }
        } else {
            locked_drawSelf(&memberData, in: rect, into: context, atScale: scale)
        }

        context.endTransparencyLayer()
        context.restoreGState()
    }

    func locked_drawSelf(_ memberData: inout MemberData, in rect: CGRect, into context: CGContext, atScale scale: CGFloat) {
        if !memberData.shouldScaleWithZoom {
            context.scaleBy(x: 1.0 / scale, y: 1.0 / scale)
        }
        let bezier = memberData.bezier
        for decoration in memberData.decorations {
            bezier.set(in: context)
            decoration.render(into: context, atScale: scale)
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
        memberData.layer = .path(layer)
        if memberData.transform != layer.transform {
            memberData.transform = layer.transform
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
        // TODO: equivalent, not equal
        if memberData.decorations != layer.decorations {
            memberData.decorations = layer.decorations
            didChange = true
        }
        if memberData.bezier != layer.bezier {
            memberData.bezier = layer.bezier
            memberData.renderedBezier = memberData.bezier
            memberData.renderedBezier.transform(memberData.transform)
            didChange = true
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
        if didChange {
            return Set([.invalidateRect(memberData.didDrawRect), .invalidateRect(locked_willDrawRect(&memberData))])
        } else {
            return Set()
        }
    }
    
    func locked_quickGlobalEffectiveBounds(_ memberData: inout MemberData) -> CGRect {
        memberData.decorations.effectiveBounds(for: memberData.renderedBezier.cgQuickBounds)
    }
}
