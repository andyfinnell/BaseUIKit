import BaseKit

public struct TextLayer<ID: Hashable & Sendable>: Hashable, Sendable, Identifiable {
    public let id: ID
    public let transform: Transform
    public let opacity: Double
    public let blendMode: BlendMode
    public let isVisible: Bool
    public let decorations: [Decoration]
    public let runs: [TextRun]
    public let autosize: Bool
    public let width: Double
    public let baseline: TextBaseline
    public let filter: FilterLayer?

    public init(
        id: ID,
        transform: Transform,
        opacity: Double,
        blendMode: BlendMode,
        isVisible: Bool,
        decorations: [Decoration],
        runs: [TextRun],
        autosize: Bool,
        width: Double,
        baseline: TextBaseline = .alphabetic,
        filter: FilterLayer? = nil
    ) {
        self.id = id
        self.transform = transform
        self.opacity = opacity
        self.blendMode = blendMode
        self.isVisible = isVisible
        self.decorations = decorations
        self.runs = runs
        self.autosize = autosize
        self.width = width
        self.baseline = baseline
        self.filter = filter
    }
}
