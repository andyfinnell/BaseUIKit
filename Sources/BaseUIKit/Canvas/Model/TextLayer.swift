import BaseKit

public struct TextLayer<ID: Hashable & Sendable>: Hashable, Sendable, Identifiable {
    public let id: ID
    public let transform: Transform
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
    public let filter: FilterLayer?

    public init(
        id: ID,
        transform: Transform,
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
        filter: FilterLayer? = nil
    ) {
        self.id = id
        self.transform = transform
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
        self.filter = filter
    }
}
