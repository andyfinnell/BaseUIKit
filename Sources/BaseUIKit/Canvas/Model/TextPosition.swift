/// An offset into a text layer's concatenated runs, measured in characters.
public struct TextPosition: Hashable, Sendable, Comparable {
    public let value: Int

    public init(_ value: Int) {
        self.value = value
    }

    public static func < (lhs: TextPosition, rhs: TextPosition) -> Bool {
        lhs.value < rhs.value
    }
}

/// A half-open range of text positions [start, end).
public struct TextRange: Hashable, Sendable {
    /// First character position (inclusive).
    public let start: TextPosition
    /// Last character position (exclusive).
    public let end: TextPosition

    public init(start: TextPosition, end: TextPosition) {
        self.start = min(start, end)
        self.end = max(start, end)
    }
}
