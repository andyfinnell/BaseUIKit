import BaseKit
import CoreText
import Foundation

public extension TextRun {
    /// CoreText font resolved from `fontName` / `fontSize` attributes,
    /// falling back to Times New Roman 16pt when either is missing.
    static func resolvedFont(from attributes: [Attribute]) -> CTFont {
        var fontName = "Times New Roman"
        var fontSize: Double = 16.0
        for attribute in attributes {
            switch attribute {
            case let .fontName(name): fontName = name
            case let .fontSize(size): fontSize = size
            case .textAlign, .letterSpacing, .wordSpacing: break
            }
        }
        return CTFontCreateWithName(fontName as CFString, fontSize, nil)
    }

    /// Baseline-to-baseline advance CoreText uses for a `\n` line break
    /// with this run's font: `ascent + descent + leading`.
    static func naturalLineHeight(from attributes: [Attribute]) -> Double {
        let font = resolvedFont(from: attributes)
        return Double(CTFontGetAscent(font))
            + Double(CTFontGetDescent(font))
            + Double(CTFontGetLeading(font))
    }
}
