/// An offset into a text layer's concatenated runs, measured in UTF-16 code units.
///
/// CoreText and NSString/NSAttributedString use UTF-16 indices internally.
/// This type stores that representation and provides safe conversion to/from
/// Swift String indices (which use grapheme clusters).
public struct TextPosition: Hashable, Sendable, Comparable {
    /// The offset in UTF-16 code units.
    public let utf16Offset: Int

    /// Creates a text position from a UTF-16 code unit offset.
    ///
    /// Use this when working with CoreText (CTLine, CFRange), NSString,
    /// or NSAttributedString APIs that return UTF-16 indices.
    public init(utf16Offset: Int) {
        self.utf16Offset = utf16Offset
    }

    /// Creates a text position from a Swift String.Index.
    ///
    /// Converts the grapheme-cluster-based String.Index to the
    /// corresponding UTF-16 offset.
    public init(stringIndex: String.Index, in string: String) {
        self.utf16Offset = stringIndex.utf16Offset(in: string)
    }

    /// Returns the end position of a string (one past the last character).
    public static func endOf(_ string: String) -> TextPosition {
        TextPosition(utf16Offset: string.utf16.count)
    }

    /// Converts this UTF-16 position to a Swift String.Index.
    ///
    /// Returns nil if the offset doesn't align to a grapheme cluster
    /// boundary (e.g. points into the middle of an emoji).
    public func stringIndex(in string: String) -> String.Index? {
        guard let utf16Index = string.utf16.index(
            string.utf16.startIndex,
            offsetBy: utf16Offset,
            limitedBy: string.utf16.endIndex
        ) else {
            return nil
        }
        // Round to the nearest grapheme cluster boundary
        return utf16Index.samePosition(in: string) ?? string.index(before: string.index(after: utf16Index))
    }

    public static func < (lhs: TextPosition, rhs: TextPosition) -> Bool {
        lhs.utf16Offset < rhs.utf16Offset
    }
}

/// A half-open range of text positions [start, end), in UTF-16 offsets.
public struct TextRange: Hashable, Sendable {
    /// First character position (inclusive).
    public let start: TextPosition
    /// One past the last character position (exclusive).
    public let end: TextPosition

    public init(start: TextPosition, end: TextPosition) {
        self.start = min(start, end)
        self.end = max(start, end)
    }
}
