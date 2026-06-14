import BaseKit

/// One positioning block inside a `TextLayer`. A layer's `blocks` list
/// renders sequentially, each with its native pipeline:
///
/// - `.framesetter` blocks go through the CT framesetter — line
///   breaking, text-anchor on this chunk, natural advances, decoration
///   runs.
/// - `.perGlyph` blocks render glyph-by-glyph using each run's explicit
///   `perGlyphOffsets` / `perGlyphRotations`. CT framesetter does NOT
///   apply.
///
/// Used today by the LayoutEngine to mix straight-baseline text and
/// path-following text (`<textPath>`) inside a single `<text>` element
/// without fragmenting it across multiple TextLayers.
public enum TextBlock: Hashable, Sendable {
    /// `anchor` is the baseline-origin offset in the layer's local
    /// space where this block begins. For a single-block layer it's
    /// `.zero` and matches today's behavior; for a block that follows
    /// another (e.g. text after a `<textPath>` sibling) it carries
    /// where the previous block left the current text position.
    case framesetter(runs: [TextRun], anchor: Vector)
    case perGlyph(runs: [TextRun])
}

public extension TextBlock {
    var runs: [TextRun] {
        switch self {
        case let .framesetter(runs, _), let .perGlyph(runs): runs
        }
    }
}
