import Foundation
import CoreGraphics
import BaseKit

@MainActor
protocol CanvasObject<ID>: AnyObject {
    associatedtype ID: Hashable & Sendable
    
    var id: ID { get }
    var didDrawRect: CGRect { get }
    var willDrawRect: CGRect { get }
    
    func invalidate()
    func draw(_ rect: CGRect, into context: CGContext)
    
    var layer: Layer<ID> { get set }
    var structurePath: BezierPath { get }
    
    func hitTest(_ location: CGPoint) -> Bool
    func intersects(_ rect: CGRect) -> Bool
    func contained(by rect: CGRect) -> Bool
    
    var canvas: CanvasDatabase<ID>? { get set }
}

@MainActor
protocol CanvasObjectDrawable: CanvasObject {
    var anchorPoint: AnchorPoint { get }
    var transform: Transform { get }
    var opacity: Double { get }
    var blendMode: BlendMode { get }
    var isVisible: Bool { get }
    var didDrawRect: CGRect { get set }
    var structureBounds: CGRect { get }
    
    func drawSelf(_ rect: CGRect, into context: CGContext)
}

extension CanvasObjectDrawable {
    func draw(_ rect: CGRect, into context: CGContext) {
        guard willDrawRect.intersects(rect) else {
            return
        }
        
        didDrawRect = willDrawRect
        
        guard isVisible else {
            return
        }
        
        context.saveGState()
        
        context.setAlpha(opacity)
        context.setBlendMode(blendMode.toCG)
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        
        let affineTransform = transform.toCG
        context.concatenate(affineTransform)
        
        drawSelf(rect, into: context)
        
        context.endTransparencyLayer()
        context.restoreGState()
    }
}

