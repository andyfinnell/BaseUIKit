import BaseKit
import Foundation

public struct PathLayer<ID: Hashable & Sendable>: Hashable, Sendable, Identifiable {
    public let id: ID
    public let transform: Transform
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

    public init(
        id: ID,
        transform: Transform = .identity,
        opacity: Double = 1.0,
        blendMode: BlendMode = .normal,
        isVisible: Bool = true,
        decorations: [Decoration] = [],
        bezier: BezierPath,
        shouldScaleWithZoom: Bool = true,
        clipPath: ClipPath? = nil,
        mask: MaskLayer? = nil,
        filter: FilterLayer? = nil,
        markers: MarkerLayer? = nil
    ) {
        self.id = id
        self.transform = transform
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
    }
}
