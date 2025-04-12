import Foundation
import CoreGraphics
import BaseKit

protocol CanvasObject<ID>: AnyObject, Sendable {
    associatedtype ID: Hashable & Sendable
    
    var id: ID { get }
    var didDrawRect: CGRect { get }
    var willDrawRect: CGRect { get }
    
    func draw(_ rect: CGRect, into context: CGContext, atScale scale: CGFloat)
    
    var layer: Layer<ID> { get }
    var structurePath: BezierPath { get }
    
    func updateLayer(_ layer: Layer<ID>) -> Set<CanvasInvalidation>
    
    func hitTest(_ location: CGPoint) -> Bool
    func intersects(_ rect: CGRect) -> Bool
    func contained(by rect: CGRect) -> Bool
}
