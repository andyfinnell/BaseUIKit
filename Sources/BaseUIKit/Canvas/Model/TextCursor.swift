import BaseKit

public struct TextCursor: Hashable, Sendable {
    /// Character position where the caret is drawn, as an offset across all concatenated runs.
    public let position: TextPosition
    public let color: Color

    public init(position: TextPosition, color: Color) {
        self.position = position
        self.color = color
    }
}

public struct TextSelection: Hashable, Sendable {
    public let range: TextRange
    public let color: Color

    public init(range: TextRange, color: Color) {
        self.range = range
        self.color = color
    }
}
