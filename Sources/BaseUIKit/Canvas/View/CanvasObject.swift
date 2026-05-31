import Foundation
import CoreGraphics
import BaseKit

protocol CanvasObject<ID>: AnyObject, Sendable {
    associatedtype ID: Hashable & Sendable

    var id: ID { get }
    var didDrawRect: CGRect { get }
    var willDrawRect: CGRect { get }

    func draw(_ rect: CGRect, into context: CGContext, atScale scale: CGFloat, renderingCache: RenderingCache?)

    var layer: Layer<ID> { get }
    var structurePath: BezierPath { get }
    var typographicBounds: CGRect? { get }
    var outlinePath: BezierPath { get }

    func updateLayer(_ layer: Layer<ID>) -> Set<CanvasInvalidation>

    /// Return the deepest matching layer at `location`. For leaf
    /// objects: `predicate(id) && self.containsHit(location)` →
    /// `[.kind(self.layer)]`, else `nil`. For containers (groups):
    /// walks children topmost-first and returns the first non-nil
    /// hit, so a click inside a group reports the actual descendant.
    func hitLayer(at location: CGPoint, atScale scale: CGFloat, including predicate: (ID) -> Bool) -> Layer<ID>?

    /// Return all layers that intersect `rect` and pass `predicate`.
    /// Leaves yield `[self]` or `[]`. Containers concatenate their
    /// descendants' results.
    func intersectingLayers(_ rect: CGRect, atScale scale: CGFloat, including predicate: (ID) -> Bool) -> [Layer<ID>]

    /// Return all layers fully contained by `rect` that pass
    /// `predicate`. Same recursive shape as `intersectingLayers`.
    func containingLayers(_ rect: CGRect, atScale scale: CGFloat, including predicate: (ID) -> Bool) -> [Layer<ID>]

    var transform: Transform { get }

    func textIndex(at location: CGPoint) -> TextPosition?
    func textRects(for range: TextRange) -> [CGRect]?
    func navigateText(_ navigation: TextNavigation, from position: TextPosition) -> TextPosition?
    func caretRect(at position: TextPosition) -> CGRect?

    func sampleColor(at canvasLocation: CGPoint) -> Color?

    /// Replace this object's children. Only `CanvasGroup` does
    /// anything meaningful with this — the default impl is a no-op so
    /// non-container layer kinds don't have to think about it.
    /// `CanvasDatabase` calls this whenever the set of children
    /// referenced by a group changes (insert / remove / reorder /
    /// re-emission of the parent's `GroupLayer.children`).
    func setChildren(_ children: [any CanvasObject<ID>])
}

extension CanvasObject {
    func sampleColor(at canvasLocation: CGPoint) -> Color? { nil }
    func setChildren(_ children: [any CanvasObject<ID>]) {}
}
