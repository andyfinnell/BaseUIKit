import Foundation
import CoreGraphics
import ImageIO
import BaseKit
import Synchronization

final class CanvasImage<ID: Hashable & Sendable>: Sendable {
    let id: ID
    var didDrawRect: CGRect { memberData.withLock { $0.didDrawRect } }
    var layer: Layer<ID> {
        memberData.withLock { $0.layer }
    }
    private let memberData: Mutex<MemberData>
    
    init(layer: ImageLayer<ID>) {
        self.id = layer.id
        self.memberData = Mutex(
            MemberData(
                didDrawRect: .zero,
                layer: .image(layer),
                transform: layer.transform,
                opacity: layer.opacity,
                blendMode: layer.blendMode,
                isVisible: layer.isVisible,
                width: layer.width,
                height: layer.height,
                imageData: layer.imageData,
                clipRect: layer.clipRect,
                filter: layer.filter,
                imageCache: nil
            )
        )
    }
}

extension CanvasImage: CanvasObject {    
    func updateLayer(_ layer: Layer<ID>) -> Set<CanvasInvalidation> {
        guard case let .image(imageLayer) = layer else {
            return Set()
        }
        return memberData.withLock {
            locked_update(&$0, with: imageLayer)
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
        memberData.withLock {
            locked_globalBounds(&$0).contains(location)
        }
    }
    
    func intersects(_ rect: CGRect) -> Bool {
        memberData.withLock {
            locked_globalBounds(&$0).intersects(rect)
        }
    }
    
    func contained(by rect: CGRect) -> Bool {
        memberData.withLock {
            rect.contains(locked_globalBounds(&$0))
        }
    }
    
    var structurePath: BezierPath {
        let globalBounds = memberData.withLock { locked_globalBounds(&$0) }
        return BezierPath(rect: Rect(globalBounds))
    }
    
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

private extension CanvasImage {
    struct MemberData {
        var didDrawRect: CGRect
        var layer: Layer<ID>
        var transform: Transform
        var opacity: Double
        var blendMode: BlendMode
        var isVisible: Bool
        var width: Double
        var height: Double
        var imageData: Data?
        var clipRect: Rect?
        var filter: FilterLayer?
        var imageCache: CGImage?
    }
    
    func locked_update(_ memberData: inout MemberData, with layer: ImageLayer<ID>) -> Set<CanvasInvalidation> {
        var didChange = false
        memberData.layer = .image(layer)
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
        if memberData.isVisible != layer.isVisible {
            memberData.isVisible = layer.isVisible
            didChange = true
        }
        if memberData.width != layer.width {
            memberData.width = layer.width
            didChange = true
        }
        if memberData.height != layer.height {
            memberData.height = layer.height
            didChange = true
        }
        if memberData.imageData != layer.imageData {
            memberData.imageData = layer.imageData
            memberData.imageCache = nil
            didChange = true
        }
        if memberData.clipRect != layer.clipRect {
            memberData.clipRect = layer.clipRect
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

    func locked_structureBounds(_ memberData: inout MemberData) -> CGRect {
        if let clipRect = memberData.clipRect {
            return clipRect.toCG
        }
        return CGRect(x: 0, y: 0, width: memberData.width, height: memberData.height)
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

        if let clipRect = memberData.clipRect {
            context.clip(to: [clipRect.toCG])
        }

        if let filter = memberData.filter {
            filter.drawFiltered(into: context, scale: scale, renderingCache: renderingCache) { targetContext in
                locked_drawSelf(&memberData, in: rect, into: targetContext, atScale: scale)
            }
        } else {
            locked_drawSelf(&memberData, in: rect, into: context, atScale: scale)
        }

        if needsTransparencyLayer {
            context.endTransparencyLayer()
        }
        context.restoreGState()
    }

    func locked_drawSelf(_ memberData: inout MemberData, in rect: CGRect, into context: CGContext, atScale scale: CGFloat) {
        let bounds = CGRect(x: 0, y: 0, width: memberData.width, height: memberData.height)

        if memberData.imageData != nil, let image = locked_image(&memberData) {
            // Flip the image (CGContext has flipped Y axis)
            context.translateBy(x: 0, y: bounds.height)
            context.scaleBy(x: 1, y: -1)
            context.draw(image, in: bounds)
        } else {
            locked_drawBrokenImagePlaceholder(&memberData, in: bounds, into: context)
        }
    }

    func locked_drawBrokenImagePlaceholder(_ memberData: inout MemberData, in bounds: CGRect, into context: CGContext) {
        let strokeWidth = max(1.0, min(bounds.width, bounds.height) * 0.02)

        // Red border rectangle
        context.setStrokeColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.setLineWidth(strokeWidth)
        let inset = strokeWidth / 2
        context.stroke(bounds.insetBy(dx: inset, dy: inset))

        // Red X from corner to corner
        context.beginPath()
        context.move(to: CGPoint(x: bounds.minX, y: bounds.minY))
        context.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
        context.move(to: CGPoint(x: bounds.maxX, y: bounds.minY))
        context.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY))
        context.strokePath()
    }

    func locked_image(_ memberData: inout MemberData) -> CGImage? {
        if let imageCache = memberData.imageCache {
            return imageCache
        }
        guard let imageData = memberData.imageData,
              let source = CGImageSourceCreateWithData(imageData as CFData,
                                                       [kCGImageSourceShouldCache: true] as CFDictionary) else {
            return nil
        }
        if let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            memberData.imageCache = image
            return image
        }
        return nil
    }

    func locked_willDrawRect(_ memberData: inout MemberData) -> CGRect {
        locked_globalBounds(&memberData)
    }
    
    func locked_globalBounds(_ memberData: inout MemberData) -> CGRect {
        memberData.transform.apply(to: locked_structureBounds(&memberData))
    }
}
