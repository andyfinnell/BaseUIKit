import BaseKit
import CoreText
import Foundation

public extension TextRun {
    /// Resolve the run's font face by reading its attributes. Prefers a
    /// `.fontRequest` if present (the SVG layout path); otherwise falls
    /// back to `.fontName`/`.fontSize` (HUD overlays, editor
    /// round-trip), defaulting to Times New Roman 16pt when neither is
    /// present.
    static func resolvedFont(from attributes: [Attribute]) -> ResolvedFont {
        if let request = fontRequest(in: attributes) {
            return FontResolver.resolve(request)
        }
        var fontName = "Times New Roman"
        var fontSize: Double = 16.0
        for attribute in attributes {
            switch attribute {
            case let .fontName(name): fontName = name
            case let .fontSize(size): fontSize = size
            case .fontRequest, .textAlign, .letterSpacing, .wordSpacing: break
            }
        }
        return ResolvedFont(postScriptName: fontName, pointSize: fontSize)
    }

    /// CoreText font for the run — convenience accessor for code that
    /// wants a `CTFont` directly. Use the `ResolvedFont` form above when
    /// you also need metrics, to avoid building the CTFont twice.
    static func resolvedCTFont(from attributes: [Attribute]) -> CTFont {
        resolvedFont(from: attributes).ctFont
    }

    /// Baseline-to-baseline advance CoreText uses for a `\n` line break
    /// with this run's font: `ascent + descent + leading`.
    static func naturalLineHeight(from attributes: [Attribute]) -> Double {
        resolvedFont(from: attributes).naturalLineHeight
    }

    private static func fontRequest(in attributes: [Attribute]) -> FontRequest? {
        for attribute in attributes {
            if case let .fontRequest(request) = attribute { return request }
        }
        return nil
    }
}
