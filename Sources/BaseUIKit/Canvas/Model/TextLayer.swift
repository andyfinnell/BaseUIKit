import BaseKit
import CoreGraphics

public struct TextLayer<ID: Hashable & Sendable>: Hashable, Sendable, Identifiable {
    public let id: ID
    /// Full transform that maps glyph-local space to canvas-global space.
    /// Includes any inherited transforms, the element's own `transform=`
    /// attribute, AND the `position` translate.
    public let transform: Transform
    /// The position-only translate component (from the text's `x`/`y`
    /// attributes). Stored separately so the canvas renderer can apply
    /// it AFTER clip-path/mask are set. Per SVG 1.1 §14.3.2, mask and
    /// clip-path geometry are interpreted in the element's user
    /// coordinate system — established by inherited + element transforms
    /// but NOT by content-positioning translates. Defaults to `.zero`.
    public let position: Vector
    public let screenOffset: Vector
    public let opacity: Double
    public let blendMode: BlendMode
    public let isVisible: Bool
    public let decorations: [Decoration]
    public let runs: [TextRun]
    public let shouldScaleWithZoom: Bool
    public let autosize: Bool
    public let width: Double
    public let baseline: TextBaseline
    public let textDecorationLines: TextDecorationLine
    public let clipPath: ClipPath?
    public let mask: MaskLayer?
    public let filter: FilterLayer?
    /// Extra screen-pt distance around the text's typographic bounds that
    /// still counts as a hit. See `PathLayer.hitPadding`.
    public let hitPadding: CGFloat

    public init(
        id: ID,
        transform: Transform,
        position: Vector,
        screenOffset: Vector = .zero,
        opacity: Double,
        blendMode: BlendMode,
        isVisible: Bool,
        decorations: [Decoration],
        runs: [TextRun],
        shouldScaleWithZoom: Bool = true,
        autosize: Bool,
        width: Double,
        baseline: TextBaseline = .alphabetic,
        textDecorationLines: TextDecorationLine = [],
        clipPath: ClipPath? = nil,
        mask: MaskLayer? = nil,
        filter: FilterLayer? = nil,
        hitPadding: CGFloat = 0
    ) {
        self.id = id
        self.transform = transform
        self.position = position
        self.screenOffset = screenOffset
        self.opacity = opacity
        self.blendMode = blendMode
        self.isVisible = isVisible
        self.decorations = decorations
        self.runs = runs
        self.shouldScaleWithZoom = shouldScaleWithZoom
        self.autosize = autosize
        self.width = width
        self.baseline = baseline
        self.textDecorationLines = textDecorationLines
        self.clipPath = clipPath
        self.mask = mask
        self.filter = filter
        self.hitPadding = hitPadding
    }
}
