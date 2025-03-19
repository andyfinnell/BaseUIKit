import Foundation
import CoreGraphics
import ImageIO
import BaseKit

@MainActor
final class CanvasImage<ID: Hashable & Sendable> {
    let id: ID
    var didDrawRect: CGRect = .zero
    var layer: Layer<ID> {
        didSet {
            updateFromLayer()
        }
    }
    
    weak var canvas: CanvasDatabase<ID>?
    
    var transform: Transform {
        didSet {
            if oldValue != transform {
                invalidate()
            }
        }
    }
    var opacity: Double {
        didSet {
            if oldValue != opacity {
                invalidate()
            }
        }
    }
    var blendMode: BlendMode {
        didSet {
            if oldValue != blendMode {
                invalidate()
            }
        }
    }
    var isVisible: Bool {
        didSet {
            if oldValue != isVisible {
                invalidate()
            }
        }
    }
    var width: Double {
        didSet {
            if oldValue != width {
                invalidate()
            }
        }
    }
    var height: Double {
        didSet {
            if oldValue != height {
                invalidate()
            }
        }
    }
    var imageData: Data {
        didSet {
            imageCache = nil
        }
    }
    
    private var imageCache: CGImage?
    
    init(layer: ImageLayer<ID>) {
        self.layer = .image(layer)
        self.id = layer.id
        self.transform = layer.transform
        self.opacity = layer.opacity
        self.blendMode = layer.blendMode
        self.isVisible = layer.isVisible
        self.width = layer.width
        self.height = layer.height
        self.imageData = layer.imageData
    }
    
}

extension CanvasImage: CanvasObjectDrawable {
    func invalidate() {
        canvas?.invalidate(self)
    }
    
    var willDrawRect: CGRect {
        globalBounds
    }
    
    var structureBounds: CGRect {
        CGRect(x: 0, y: 0, width: width, height: height)
    }
    
    func drawSelf(_ rect: CGRect, into context: CGContext, atScale scale: CGFloat) {
        // Flip the image
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        if let image {
            context.draw(image, in: bounds)
        }
    }
    
    func hitTest(_ location: CGPoint) -> Bool {
        globalBounds.contains(location)
    }
    
    func intersects(_ rect: CGRect) -> Bool {
        globalBounds.intersects(rect)
    }
    
    func contained(by rect: CGRect) -> Bool {
        rect.contains(globalBounds)
    }
    
    var structurePath: BezierPath {
        BezierPath(rect: Rect(globalBounds))
    }
}

private extension CanvasImage {
    func updateFromLayer() {
        guard case let .image(imageLayer) = layer else {
            return
        }
        update(with: imageLayer)
    }
    
    func update(with layer: ImageLayer<ID>) {
        self.transform = layer.transform
        self.opacity = layer.opacity
        self.blendMode = layer.blendMode
        self.width = layer.width
        self.height = layer.height
        self.imageData = layer.imageData
    }

    var image: CGImage? {
        if let imageCache {
            return imageCache
        }
        guard let source = CGImageSourceCreateWithData(imageData as CFData,
                                                       [kCGImageSourceShouldCache: true] as CFDictionary) else {
            return nil
        }
        if let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            imageCache = image
            return image
        }
        return nil
    }

    var globalBounds: CGRect {
        transform.apply(to: structureBounds)
    }
}
