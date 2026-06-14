import BaseKit
import CoreText
import Foundation

/// CT-backed text measurement helpers exposed to producers that need
/// glyph advances *before* they build a `TextLayer` — currently
/// LayoutEngine's `<textPath>` path. Keeps CT out of LayoutEngine so the
/// 1218 separation holds.
public enum TextShaper {
    /// Returns the natural x-advance of each character in `text` shaped
    /// with `font`. Ligatures are disabled so the returned advances are
    /// indexed 1:1 with characters — matching the
    /// `TextRun.perGlyphOffsets` indexing rule that per-glyph placement
    /// breaks ligatures (see [[1094]] / [[1095]] / [[1096]]).
    ///
    /// `letterSpacing` is added to every advance (positive widens,
    /// negative tightens). Cross-character kerning is preserved when the
    /// font's `kern` feature is enabled.
    public static func characterAdvances(
        of text: String, font: ResolvedFont, letterSpacing: Double = 0
    ) -> [Double] {
        guard !text.isEmpty else { return [] }

        let line = makeLine(text: text, font: font, letterSpacing: letterSpacing)
        let utf16 = text.utf16
        guard !utf16.isEmpty else { return [] }

        var advances: [Double] = []
        advances.reserveCapacity(utf16.count)
        var previousOffset = CTLineGetOffsetForStringIndex(line, 0, nil)
        for index in 1...utf16.count {
            let offset = CTLineGetOffsetForStringIndex(line, index, nil)
            advances.append(Double(offset - previousOffset))
            previousOffset = offset
        }
        return advances
    }

    /// Total natural x-advance of the line — the sum of
    /// `characterAdvances`. Convenience for the text-anchor shift in
    /// `<textPath>` layout, computed in one CT call rather than walking
    /// the array.
    public static func totalAdvance(
        of text: String, font: ResolvedFont, letterSpacing: Double = 0
    ) -> Double {
        guard !text.isEmpty else { return 0 }
        let line = makeLine(text: text, font: font, letterSpacing: letterSpacing)
        let utf16Count = text.utf16.count
        return Double(CTLineGetOffsetForStringIndex(line, utf16Count, nil))
    }
}

private extension TextShaper {
    static func makeLine(text: String, font: ResolvedFont, letterSpacing: Double) -> CTLine {
        var attrs: [NSAttributedString.Key: Any] = [
            .font: font.ctFont,
            // Disable ligatures so character index aligns 1:1 with
            // glyph index — required by `perGlyphOffsets` semantics.
            .ligature: 0,
        ]
        if letterSpacing != 0 {
            attrs[.kern] = letterSpacing
        }
        let attributed = NSAttributedString(string: text, attributes: attrs)
        return CTLineCreateWithAttributedString(attributed)
    }
}
