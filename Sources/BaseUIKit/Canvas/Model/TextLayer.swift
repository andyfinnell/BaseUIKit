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
    /// Ordered list of positioning blocks. Each block renders with its
    /// native pipeline (framesetter or per-glyph). For straight-baseline
    /// text (the common case) this is a single `.framesetter` block;
    /// `<textPath>` and per-character positioning produce mixed lists.
    public let blocks: [TextBlock]
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
        blocks: [TextBlock],
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
        self.blocks = blocks
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

    /// Backward-compatible init that wraps a flat run list into a single
    /// block. The block kind is auto-picked: any run with per-glyph data
    /// produces a `.perGlyph` block, otherwise a `.framesetter` block at
    /// anchor `.zero`. New callers that need block mixing construct
    /// `blocks:` directly.
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
        let block: TextBlock =
            runs.contains(where: \.needsPerGlyphRendering)
            ? .perGlyph(runs: runs)
            : .framesetter(runs: runs, anchor: .zero)
        self.init(
            id: id,
            transform: transform,
            position: position,
            screenOffset: screenOffset,
            opacity: opacity,
            blendMode: blendMode,
            isVisible: isVisible,
            decorations: decorations,
            blocks: [block],
            shouldScaleWithZoom: shouldScaleWithZoom,
            autosize: autosize,
            width: width,
            baseline: baseline,
            textDecorationLines: textDecorationLines,
            clipPath: clipPath,
            mask: mask,
            filter: filter,
            hitPadding: hitPadding
        )
    }
}

public extension TextLayer {
    /// Flat run list across all blocks. Convenient for readers (bounds,
    /// debug overlays, hit-test glyph iteration) that don't need to know
    /// which positioning block each run belongs to. For multi-block
    /// layers, layer-wide CT queries built off this list treat the runs
    /// as one continuous stream — that's correct for single-block layers
    /// and an approximation for mixed ones.
    var runs: [TextRun] {
        blocks.flatMap(\.runs)
    }
}
