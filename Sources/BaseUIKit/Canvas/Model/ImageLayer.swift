import Foundation
import BaseKit

public struct ImageLayer<ID: Hashable & Sendable>: Hashable, Sendable, Identifiable {
    public let id: ID
    /// Full transform that maps image-local space to canvas-global space.
    /// Includes any inherited transforms, the element's own `transform=`
    /// attribute, AND the `position` translate.
    public let transform: Transform
    /// The position-only translate component (from the image's `x`/`y`
    /// attributes plus any `preserveAspectRatio` offset). Stored
    /// separately so the canvas renderer can apply it AFTER
    /// clip-path/mask are set. Per SVG 1.1 §14.3.2, mask and clip-path
    /// geometry are interpreted in the element's user coordinate system
    /// — established by inherited + element transforms but NOT by
    /// content-positioning translates. Defaults to `.zero`.
    public let position: Vector
    public let opacity: Double
    public let blendMode: BlendMode
    public let isVisible: Bool
    public let width: Double
    public let height: Double
    public let imageData: Data?
    public let sourceLabel: String?
    public let clipRect: Rect?
    public let clipPath: ClipPath?
    public let mask: MaskLayer?
    public let filter: FilterLayer?

    public init(
        id: ID,
        transform: Transform,
        position: Vector,
        opacity: Double,
        blendMode: BlendMode,
        isVisible: Bool,
        width: Double,
        height: Double,
        imageData: Data?,
        sourceLabel: String? = nil,
        clipRect: Rect? = nil,
        clipPath: ClipPath? = nil,
        mask: MaskLayer? = nil,
        filter: FilterLayer? = nil
    ) {
        self.id = id
        self.transform = transform
        self.position = position
        self.opacity = opacity
        self.blendMode = blendMode
        self.isVisible = isVisible
        self.width = width
        self.height = height
        self.imageData = imageData
        self.sourceLabel = sourceLabel
        self.clipRect = clipRect
        self.clipPath = clipPath
        self.mask = mask
        self.filter = filter
    }
}
