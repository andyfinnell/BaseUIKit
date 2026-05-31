import BaseKit
import Foundation

/// A canvas layer that groups other layers under a shared opacity / blend
/// mode and optional clip-path, mask, and filter. Mirrors the SVG `<g>`
/// rendering semantics: the children are rendered as a unit, with the
/// group's effects applied to the combined rendering rather than to each
/// child independently.
///
/// Children are stored by ID rather than by value. The actual child layers
/// live in `CanvasDatabase`'s object dictionary (`objectById`); the group
/// only records membership and order. This keeps a child's content update
/// to a single dictionary write and avoids re-emitting the parent group
/// every time a descendant changes.
public struct GroupLayer<ID: Hashable & Sendable>: Hashable, Sendable, Identifiable {
    public let id: ID
    public let opacity: Double
    public let blendMode: BlendMode
    public let isVisible: Bool
    public let clipPath: ClipPath?
    public let mask: MaskLayer?
    public let filter: FilterLayer?
    /// Child layer IDs in render order (back to front). The IDs are looked
    /// up against the canvas's object dictionary at render time.
    public let children: [ID]

    public init(
        id: ID,
        opacity: Double = 1.0,
        blendMode: BlendMode = .normal,
        isVisible: Bool = true,
        clipPath: ClipPath? = nil,
        mask: MaskLayer? = nil,
        filter: FilterLayer? = nil,
        children: [ID] = []
    ) {
        self.id = id
        self.opacity = opacity
        self.blendMode = blendMode
        self.isVisible = isVisible
        self.clipPath = clipPath
        self.mask = mask
        self.filter = filter
        self.children = children
    }

    /// True when the group has no effects that require an offscreen pass.
    /// `drawGroup` uses this to skip transparency-layer machinery and
    /// render children straight into the parent context.
    public var hasNoEffects: Bool {
        opacity == 1.0
            && blendMode == .normal
            && clipPath == nil
            && mask == nil
            && filter == nil
    }

    /// Returns a copy with the children list replaced. Used by
    /// `CanvasDatabase` when inserting / removing / reordering layers
    /// inside a group: child membership changes through this method
    /// rather than through a fresh emission from the LayoutEngine.
    public func replacingChildren(_ newChildren: [ID]) -> GroupLayer<ID> {
        GroupLayer(
            id: id,
            opacity: opacity,
            blendMode: blendMode,
            isVisible: isVisible,
            clipPath: clipPath,
            mask: mask,
            filter: filter,
            children: newChildren
        )
    }
}
