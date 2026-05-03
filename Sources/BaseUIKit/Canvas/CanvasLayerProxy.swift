import BaseKit
import Observation

/// An observable view onto one canvas object's bounds in **view-space**
/// coordinates. Vended by `CanvasDatabase.layerProxy(for:)`; the database
/// keeps the proxy current as long as the caller retains it.
///
/// `viewBounds` is the layer's outer rendered rect (i.e. its
/// `willDrawRect` projected through the canvas's content + viewport
/// transforms). For a `ComputedLayer`, `viewBounds` is the union of all
/// generated sub-objects' rects. `nil` means the layer isn't currently in
/// the canvas — the proxy will populate when it appears.
///
/// SwiftUI views that need to anchor on a canvas layer should hold a
/// proxy in `@State` and read `viewBounds` / `viewCenter` from their
/// body — `@Observable` triggers re-evaluation when the canvas updates.
@MainActor
@Observable
public final class CanvasLayerProxy<ID: Hashable & Sendable> {
    public let id: ID
    public internal(set) var viewBounds: Rect?

    public var viewCenter: Point? {
        viewBounds.map { Point(x: $0.midX, y: $0.midY) }
    }

    init(id: ID, viewBounds: Rect?) {
        self.id = id
        self.viewBounds = viewBounds
    }
}

/// Weak box stored in the canvas's proxy cache. The proxy's lifetime is
/// owned by the consumer (caller of `layerProxy(for:)`); the canvas only
/// keeps a weak reference so dropping the proxy stops tracking.
struct WeakCanvasLayerProxy<ID: Hashable & Sendable>: Sendable {
    weak var value: CanvasLayerProxy<ID>?
}
