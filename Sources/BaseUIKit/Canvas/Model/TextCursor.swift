import BaseKit

public struct TextCursor: Hashable, Sendable {
    /// Character index where the caret is drawn, as an offset across all concatenated runs.
    public let position: Int
    public let color: Color

    public init(position: Int, color: Color) {
        self.position = position
        self.color = color
    }
}

public struct TextSelection: Hashable, Sendable {
    /// First selected character index (inclusive).
    public let start: Int
    /// Last selected character index (exclusive).
    public let end: Int
    public let color: Color

    public init(start: Int, end: Int, color: Color) {
        self.start = min(start, end)
        self.end = max(start, end)
        self.color = color
    }
}
