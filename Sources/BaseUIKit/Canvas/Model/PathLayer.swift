import BaseKit
import Foundation

public struct PathLayer<ID: Hashable & Sendable>: Hashable, Sendable, Identifiable {
    public let id: ID
    public let transform: Transform
    public let screenOffset: Vector
    public let opacity: Double
    public let blendMode: BlendMode
    public let isVisible: Bool
    public let decorations: [Decoration]
    public let bezier: BezierPath
    public let shouldScaleWithZoom: Bool
    public let clipPath: ClipPath?
    public let mask: MaskLayer?
    public let filter: FilterLayer?
    public let markers: MarkerLayer?
    /// Extra screen-pt distance around the path that still counts as a hit.
    /// Stays in screen-pt regardless of zoom — the hit-test converts to
    /// doc-pt at the current scale. Default `0` preserves prior behavior.
    public let hitPadding: CGFloat
    /// When `true`, the layer is skipped in the draw pass (and contributes
    /// nothing to invalidation rects) but still participates in hit-testing.
    /// Used to attach an invisible hit affordance to a sibling visible layer.
    public let hitOnly: Bool

    public init(
        id: ID,
        transform: Transform = .identity,
        screenOffset: Vector = .zero,
        opacity: Double = 1.0,
        blendMode: BlendMode = .normal,
        isVisible: Bool = true,
        decorations: [Decoration] = [],
        bezier: BezierPath,
        shouldScaleWithZoom: Bool = true,
        clipPath: ClipPath? = nil,
        mask: MaskLayer? = nil,
        filter: FilterLayer? = nil,
        markers: MarkerLayer? = nil,
        hitPadding: CGFloat = 0,
        hitOnly: Bool = false
    ) {
        self.id = id
        self.transform = transform
        self.screenOffset = screenOffset
        self.opacity = opacity
        self.blendMode = blendMode
        self.isVisible = isVisible
        self.decorations = decorations
        self.bezier = bezier
        self.shouldScaleWithZoom = shouldScaleWithZoom
        self.clipPath = clipPath
        self.mask = mask
        self.filter = filter
        self.markers = markers
        self.hitPadding = hitPadding
        self.hitOnly = hitOnly
    }
}
