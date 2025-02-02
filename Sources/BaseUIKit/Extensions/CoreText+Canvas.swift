import Foundation
import CoreText

public extension CTFrame {
    var lines: [CTLine] {
        (CTFrameGetLines(self) as? [CTLine]) ?? []
    }
    
    var lineOrigins: [CGPoint] {
        var lineOrigins = Array<CGPoint>(repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(self, CFRange(location: 0, length: 0), &lineOrigins)
        return lineOrigins
    }
}

public extension CTLine {
    var runs: [CTRun] {
        (CTLineGetGlyphRuns(self) as? [CTRun]) ?? []
    }
}

public extension CTRun {
    struct TypographicBounds {
        public let width: CGFloat
        public let ascent: CGFloat
        public let descent: CGFloat
        public let leading: CGFloat
    }
    
    var typographicBounds: TypographicBounds {
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let width = CTRunGetTypographicBounds(self, CFRange(location: 0, length: 0), &ascent, &descent, &leading)
        return TypographicBounds(
            width: width,
            ascent: ascent,
            descent: descent,
            leading: leading
        )
    }
    
    func imageBounds(in context: CGContext) -> CGRect {
        CTRunGetImageBounds(self, context, CFRange(location: 0, length: 0))
    }
    
    var attributes: [NSAttributedString.Key: Any] {
        (CTRunGetAttributes(self) as? [NSAttributedString.Key: Any]) ?? [:]
    }
    
    var font: NativeFont {
        (attributes[.font] as? NativeFont) ?? NativeFont.systemFont(ofSize: 12)
    }
    
    var glyphs: [CGGlyph] {
        var glyphs = Array<CGGlyph>(repeating: .zero, count: CTRunGetGlyphCount(self))
        CTRunGetGlyphs(self, CFRange(location: 0, length: CTRunGetGlyphCount(self)), &glyphs)
        return glyphs
    }
    
    var positions: [CGPoint] {
        var positions = Array<CGPoint>(repeating: .zero, count: CTRunGetGlyphCount(self))
        CTRunGetPositions(self, CFRange(location: 0, length: CTRunGetGlyphCount(self)), &positions)
        return positions
    }
    
    var range: CFRange {
        CTRunGetStringRange(self)
    }
}
