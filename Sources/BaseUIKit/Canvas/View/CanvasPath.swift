import Foundation
import CoreGraphics
import BaseKit

@MainActor
final class CanvasPath<ID: Hashable & Sendable> {
    let id: ID
    var didDrawRect: CGRect = .zero
    var layer: Layer<ID> {
        didSet {
            updateFromLayer()
        }
    }
    
    weak var canvas: CanvasDatabase<ID>?
    
    var anchorPoint: AnchorPoint {
        didSet {
            if oldValue != anchorPoint {
                invalidate()
            }
        }
    }
    
    var transform: Transform {
        didSet {
            if oldValue != transform {
                updateRenderedBezier()
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
    
    var decorations: [Decoration] {
        didSet {
            if oldValue != decorations {
                invalidate()
            }
        }
    }
    
    var bezier: BezierPath {
        didSet {
            if oldValue != bezier {
                invalidate()
            }
        }
    }

    private var renderedBezier: BezierPath
    
    init(layer: PathLayer<ID>) {
        self.layer = .path(layer)
        self.id = layer.id
        self.anchorPoint = layer.anchorPoint
        self.transform = layer.transform
        self.opacity = layer.opacity
        self.blendMode = layer.blendMode
        self.isVisible = layer.isVisible
        self.decorations = layer.decorations
        self.bezier = layer.bezier
        self.renderedBezier = layer.bezier
        renderedBezier.transform(layer.transform)
    }
    
}

extension CanvasPath: CanvasObjectDrawable {
    func invalidate() {
        canvas?.invalidate(self)
    }
    
    var willDrawRect: CGRect {
        quickGlobalEffectiveBounds
    }
    
    var structureBounds: CGRect {
        renderedBezier.cgPath.boundingBoxOfPath
    }
    
    func drawSelf(_ rect: CGRect, into context: CGContext) {
        for decoration in decorations {
            bezier.set(in: context)
            decoration.render(into: context)
        }
    }
    
    func hitTest(_ location: CGPoint) -> Bool {
        if hasFill && renderedBezier.cgPath.contains(location) {
            return true
        } else {
            let width = strokeWidth
            let distance = renderedBezier.distance(to: Point(location))
            return distance <= width
        }
    }
    
    func intersects(_ rect: CGRect) -> Bool {
        renderedBezier.cgPath.intersects(CGPath(rect: rect, transform: nil))
    }
    
    func contained(by rect: CGRect) -> Bool {
        rect.contains(renderedBezier.cgPath.boundingBoxOfPath)
    }

    var structurePath: BezierPath { renderedBezier }
}

private extension CanvasPath {
    var hasFill: Bool {
        decorations.contains {
            if case .fill = $0 {
                return true
            } else {
                return false
            }
        }
    }
    
    var strokeWidth: CGFloat {
        decorations.map {
            if case let .stroke(stroke) = $0 {
                return stroke.width
            } else {
                return 0
            }
        }.max() ?? 0
    }
    
    func updateFromLayer() {
        guard case let .path(pathLayer) = layer else {
            return
        }
        update(with: pathLayer)
    }
    
    func update(with layer: PathLayer<ID>) {
        self.anchorPoint = layer.anchorPoint
        self.transform = layer.transform
        self.opacity = layer.opacity
        self.blendMode = layer.blendMode
        self.decorations = layer.decorations
        self.bezier = layer.bezier
        updateRenderedBezier()
    }

    func updateRenderedBezier() {
        invalidate() // old position
        renderedBezier = bezier
        renderedBezier.transform(transform)
        invalidate() // new position
    }
    
    var quickGlobalEffectiveBounds: CGRect {
        decorations.effectiveBounds(for: renderedBezier.cgQuickBounds)
    }
}
