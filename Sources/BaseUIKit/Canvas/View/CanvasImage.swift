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
        
    func draw(_ rect: CGRect, into context: CGContext, atScale scale: CGFloat) {
        memberData.withLock {
            locked_draw(&$0, in: rect, into: context, atScale: scale)
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
        var imageData: Data
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
        if didChange {
            return Set([.invalidateRect(memberData.didDrawRect), .invalidateRect(locked_willDrawRect(&memberData))])
        } else {
            return Set()
        }
    }

    func locked_structureBounds(_ memberData: inout MemberData) -> CGRect {
        CGRect(x: 0, y: 0, width: memberData.width, height: memberData.height)
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
        
        locked_drawSelf(&memberData, in: rect, into: context, atScale: scale)
        
        context.endTransparencyLayer()
        context.restoreGState()
    }

    func locked_drawSelf(_ memberData: inout MemberData, in rect: CGRect, into context: CGContext, atScale scale: CGFloat) {
        // Flip the image
        let bounds = CGRect(x: 0, y: 0, width: memberData.width, height: memberData.height)
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        if let image = locked_image(&memberData) {
            context.draw(image, in: bounds)
        }
    }

    func locked_image(_ memberData: inout MemberData) -> CGImage? {
        if let imageCache = memberData.imageCache {
            return imageCache
        }
        guard let source = CGImageSourceCreateWithData(memberData.imageData as CFData,
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
