import BaseKit
import CoreGraphics
import Foundation
import Synchronization

/// Runtime representation of a `GroupLayer` in the canvas. Holds direct
/// references to its child `CanvasObject`s so it can draw, hit-test, and
/// aggregate bounds without going back to the database. `CanvasDatabase`
/// keeps the child references in sync with `GroupLayer.children` via
/// `setChildren(_:)` whenever the group's membership changes.
///
/// The database treats this object identically to any other
/// `CanvasObject` — the render pass calls `draw(...)`, hit-testing calls
/// `hitLayer(...)`, etc. — so there is no special-casing for groups
/// outside this file.
final class CanvasGroup<ID: Hashable & Sendable>: Sendable {
    let id: ID

    private let memberData: Mutex<MemberData>

    init(layer: GroupLayer<ID>) {
        self.id = layer.id
        memberData = Mutex(
            MemberData(
                layer: layer,
                children: [],
                cachedMaskImage: nil,
                lastDrawnBounds: .zero
            )
        )
    }
}

extension CanvasGroup: CanvasObject {
    var layer: Layer<ID> {
        memberData.withLock { .group($0.layer) }
    }

    var didDrawRect: CGRect {
        memberData.withLock { $0.lastDrawnBounds }
    }

    var willDrawRect: CGRect {
        // Re-compute on demand from children — willDrawRect is the
        // union of descendants expanded by the group's filter region.
        // Snapshot the children/filter under the lock, then walk
        // children outside it so child locks aren't acquired nested.
        let (children, filter): ([any CanvasObject<ID>], FilterLayer?) =
            memberData.withLock { ($0.children, $0.layer.filter) }
        let childUnion = children.lazy.map(\.willDrawRect).reduce(CGRect?.none) {
            $0?.union($1) ?? $1
        }
        switch (childUnion, filter) {
        case let (childUnion?, filter?): return childUnion.union(filter.region.toCG)
        case let (childUnion?, nil): return childUnion
        case let (nil, filter?): return filter.region.toCG
        case (nil, nil): return .zero
        }
    }

    var structurePath: BezierPath {
        let children: [any CanvasObject<ID>] = memberData.withLock { $0.children }
        return children.reduce(into: BezierPath()) { union, child in
            union.append(child.structurePath)
        }
    }

    var typographicBounds: CGRect? { nil }

    var outlinePath: BezierPath { structurePath }

    var transform: Transform { .identity }

    func draw(_ rect: CGRect, into context: CGContext, atScale scale: CGFloat, renderingCache: RenderingCache?) {
        let snapshot: DrawSnapshot? = memberData.withLock { md in
            guard md.layer.isVisible else { return nil }
            if md.layer.mask != nil, md.cachedMaskImage == nil {
                md.cachedMaskImage = md.layer.mask?.renderToMaskImage(scale: scale)
            }
            let effects = LayerEffects(
                opacity: md.layer.opacity,
                blendMode: md.layer.blendMode,
                transform: .identity,
                clipPath: md.layer.clipPath,
                mask: md.layer.mask,
                maskImage: md.cachedMaskImage,
                contentTransform: .identity,
                filter: md.layer.filter
            )
            return DrawSnapshot(effects: effects, children: md.children)
        }
        guard let snapshot else { return }

        snapshot.effects.draw(in: context, atScale: scale, renderingCache: renderingCache) { target in
            for child in snapshot.children {
                child.draw(rect, into: target, atScale: scale, renderingCache: renderingCache)
            }
        }

        // Update didDrawRect from the actual draw rects the children
        // recorded. Compute outside the lock; commit under it.
        let drawnUnion = snapshot.children.lazy.map(\.didDrawRect).reduce(CGRect?.none) {
            $0?.union($1) ?? $1
        } ?? .zero
        memberData.withLock { $0.lastDrawnBounds = drawnUnion }
    }

    func updateLayer(_ layer: Layer<ID>) -> Set<CanvasInvalidation> {
        guard case let .group(newLayer) = layer else { return [] }
        return memberData.withLock { md in
            guard md.layer != newLayer else { return [] }
            var invalidates: Set<CanvasInvalidation> = []
            if md.lastDrawnBounds != .zero {
                invalidates.insert(.invalidateRect(md.lastDrawnBounds))
            }
            if md.layer.mask != newLayer.mask {
                md.cachedMaskImage = nil
            }
            md.layer = newLayer
            return invalidates
        }
    }

    func hitLayer(at location: CGPoint, atScale scale: CGFloat, including predicate: (ID) -> Bool) -> Layer<ID>? {
        let (children, isVisible) = memberData.withLock { ($0.children, $0.layer.isVisible) }
        guard isVisible else { return nil }
        // Manual reverse loop rather than `compactMap(...).first` so the
        // non-escaping `predicate` closure isn't pulled into a lazy
        // sequence (which would make it escape).
        for child in children.reversed() {
            if let hit = child.hitLayer(at: location, atScale: scale, including: predicate) {
                return hit
            }
        }
        return nil
    }

    func intersectingLayers(_ rect: CGRect, atScale scale: CGFloat, including predicate: (ID) -> Bool) -> [Layer<ID>] {
        let (children, isVisible) = memberData.withLock { ($0.children, $0.layer.isVisible) }
        guard isVisible else { return [] }
        return children.flatMap { $0.intersectingLayers(rect, atScale: scale, including: predicate) }
    }

    func containingLayers(_ rect: CGRect, atScale scale: CGFloat, including predicate: (ID) -> Bool) -> [Layer<ID>] {
        let (children, isVisible) = memberData.withLock { ($0.children, $0.layer.isVisible) }
        guard isVisible else { return [] }
        return children.flatMap { $0.containingLayers(rect, atScale: scale, including: predicate) }
    }

    func textIndex(at location: CGPoint) -> TextPosition? { nil }
    func textRects(for range: TextRange) -> [CGRect]? { nil }
    func navigateText(_ navigation: TextNavigation, from position: TextPosition) -> TextPosition? { nil }
    func caretRect(at position: TextPosition) -> CGRect? { nil }

    func setChildren(_ children: [any CanvasObject<ID>]) {
        memberData.withLock { $0.children = children }
    }
}

private extension CanvasGroup {
    struct MemberData {
        var layer: GroupLayer<ID>
        var children: [any CanvasObject<ID>]
        var cachedMaskImage: CGImage?
        var lastDrawnBounds: CGRect
    }

    struct DrawSnapshot {
        var effects: LayerEffects
        var children: [any CanvasObject<ID>]
    }
}
