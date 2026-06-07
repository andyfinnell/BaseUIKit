import BaseKit
import CoreText
import Foundation

/// A platform font resolved from a `FontRequest`, plus the CoreText
/// metric accessors callers need.
///
/// `pointSize` is the final rendered size after any SVG
/// `font-size-adjust` correction has been applied. `postScriptName` is
/// the resolved face's PostScript name (suitable for
/// `NSFont(name:size:)` / `UIFont(name:size:)`).
public struct ResolvedFont: Hashable, Sendable {
    public let postScriptName: String
    public let pointSize: Double

    public init(postScriptName: String, pointSize: Double) {
        self.postScriptName = postScriptName
        self.pointSize = pointSize
    }
}

extension ResolvedFont {
    /// CoreText font built from this resolved face — used internally by
    /// metric accessors. Callers in the rendering layer that already
    /// hold a `CTFont` should prefer to use it directly.
    public var ctFont: CTFont {
        CTFontCreateWithName(postScriptName as CFString, pointSize, nil)
    }

    /// X-height in points at the resolved point size.
    public var xHeight: Double { Double(CTFontGetXHeight(ctFont)) }

    /// Ascent in points at the resolved point size.
    public var ascent: Double { Double(CTFontGetAscent(ctFont)) }

    /// Descent in points at the resolved point size.
    public var descent: Double { Double(CTFontGetDescent(ctFont)) }

    /// Leading (line gap) in points at the resolved point size.
    public var leading: Double { Double(CTFontGetLeading(ctFont)) }

    /// Cap height (top of an uppercase letter, above the baseline) in
    /// points at the resolved point size.
    public var capHeight: Double { Double(CTFontGetCapHeight(ctFont)) }

    /// Natural line height — baseline-to-baseline advance for a `\n`
    /// line break: `ascent + descent + leading`.
    public var naturalLineHeight: Double { ascent + descent + leading }

    /// Y offset (SVG-y-down: positive = visually down) to apply when
    /// rendering subscript glyphs. Reads `ySubscriptYOffset` from the
    /// OS/2 table when available; falls back to ~half the descent.
    public var subscriptOffset: Double {
        if let m = os2Metrics { return m.subscriptYOffset }
        return descent * 0.5
    }

    /// Y offset (SVG-y-down: negative = visually up) to apply when
    /// rendering superscript glyphs. Reads `ySuperscriptYOffset` from
    /// the OS/2 table when available; falls back to ~40% of the ascent.
    public var superscriptOffset: Double {
        if let m = os2Metrics { return -m.superscriptYOffset }
        return -ascent * 0.4
    }

    /// Offset (SVG-y-down) from the alphabetic baseline to the named
    /// baseline of this font. Used to compute `alignment-baseline`
    /// shifts: a child run with `alignment-baseline: hanging` wants its
    /// hanging baseline at the parent's dominant-baseline Y; the
    /// required visual shift is `parentBaselineOffset - childBaselineOffset(.hanging)`.
    public func baselineOffset(for baseline: TextBaseline) -> Double {
        switch baseline {
        case .alphabetic: 0
        case .top: -ascent
        case .bottom: descent
        case .middle: -xHeight * 0.5
        case .central: -(ascent - descent) * 0.5
        case .hanging: -ascent * 0.8
        case .mathematical: -xHeight * 0.5
        }
    }
}

private struct OS2Metrics {
    let subscriptYOffset: Double
    let superscriptYOffset: Double
}

private extension ResolvedFont {
    /// Parse the OS/2 table's subscript/superscript Y offsets and scale
    /// them to point size. Returns nil if the table is missing, too
    /// short, or the font's `unitsPerEm` is zero.
    var os2Metrics: OS2Metrics? {
        let tag = CTFontTableTag(kCTFontTableOS2)
        guard let cfData = CTFontCopyTable(ctFont, tag, .init(rawValue: 0)) else { return nil }
        let data = cfData as Data
        guard data.count >= 26 else { return nil }
        let unitsPerEm = Double(CTFontGetUnitsPerEm(ctFont))
        guard unitsPerEm > 0 else { return nil }
        let subY = Double(readInt16BE(data, at: 16))
        let superY = Double(readInt16BE(data, at: 24))
        let scale = pointSize / unitsPerEm
        return OS2Metrics(
            subscriptYOffset: subY * scale,
            superscriptYOffset: superY * scale)
    }
}

private func readInt16BE(_ data: Data, at offset: Int) -> Int16 {
    let hi = UInt16(data[data.startIndex + offset])
    let lo = UInt16(data[data.startIndex + offset + 1])
    return Int16(bitPattern: (hi << 8) | lo)
}

/// Translates a `FontRequest` into a `ResolvedFont`. Owns all CoreText
/// font-matching specifics — callers don't need to import CoreText.
public enum FontResolver {
    public static func resolve(_ request: FontRequest) -> ResolvedFont {
        let baseName = resolveFamilyName(
            request.families,
            weight: request.weight,
            italic: request.italic,
            widthTrait: request.widthTrait,
            smallCaps: request.smallCaps)
        let adjustedSize = adjustedSize(
            for: baseName,
            requestedSize: request.pointSize,
            aspectRatio: request.sizeAdjustAspect)
        return ResolvedFont(postScriptName: baseName, pointSize: adjustedSize)
    }

    /// CSS generic family → ordered preferred-face list. Public so
    /// platform-specific overlays can share the same expansion.
    public static func candidates(forFamily name: String) -> [String] {
        switch name.lowercased() {
        case "serif": ["Times New Roman", "Times"]
        case "sans-serif": ["Helvetica Neue", "Helvetica"]
        case "monospace": ["Menlo", "Courier New", "Courier"]
        case "cursive": ["Apple Chancery", "Snell Roundhand"]
        case "fantasy": ["Papyrus"]
        case "ui-serif": ["New York", "Georgia"]
        case "ui-monospace": ["SF Mono", "Menlo"]
        default: [name]
        }
    }

    public static func isSystemUIFamily(_ name: String) -> Bool {
        switch name.lowercased() {
        case "system-ui", "ui-sans-serif", "ui-rounded": true
        default: false
        }
    }

    /// Test-only access to the descriptor we hand CoreText — lets tests
    /// verify the traits + feature settings we asked for without
    /// depending on whether the host has the requested face installed.
    public static func test_fontDescriptor(for request: FontRequest) -> CTFontDescriptor {
        fontDescriptor(
            family: request.families.first ?? "Times",
            weight: request.weight,
            italic: request.italic,
            widthTrait: request.widthTrait,
            smallCaps: request.smallCaps)
    }
}

private extension FontResolver {
    static func resolveFamilyName(
        _ families: [String],
        weight: Double,
        italic: Bool,
        widthTrait: Double?,
        smallCaps: Bool
    ) -> String {
        for name in families {
            if isSystemUIFamily(name) {
                return systemFontPostScriptName(
                    weight: weight, italic: italic,
                    widthTrait: widthTrait, smallCaps: smallCaps)
            }
            for candidate in candidates(forFamily: name) {
                if let resolved = matchFont(
                    family: candidate, weight: weight, italic: italic,
                    widthTrait: widthTrait, smallCaps: smallCaps)
                {
                    return resolved
                }
            }
        }
        return matchFont(
            family: "Times", weight: weight, italic: italic,
            widthTrait: widthTrait, smallCaps: smallCaps)
            ?? systemFontPostScriptName(
                weight: weight, italic: italic,
                widthTrait: widthTrait, smallCaps: smallCaps)
    }

    static func matchFont(
        family: String, weight: Double, italic: Bool,
        widthTrait: Double?, smallCaps: Bool
    ) -> String? {
        let descriptor = fontDescriptor(
            family: family, weight: weight, italic: italic,
            widthTrait: widthTrait, smallCaps: smallCaps)
        let font = CTFontCreateWithFontDescriptor(descriptor, 12.0, nil)
        let actualFamily = CTFontCopyFamilyName(font) as String
        guard actualFamily.caseInsensitiveCompare(family) == .orderedSame else {
            return nil
        }
        return CTFontCopyPostScriptName(font) as String
    }

    static func fontDescriptor(
        family: String, weight: Double, italic: Bool,
        widthTrait: Double?, smallCaps: Bool
    ) -> CTFontDescriptor {
        var attrs: [String: Any] = [
            kCTFontFamilyNameAttribute as String: family,
            kCTFontTraitsAttribute as String: fontTraits(
                weight: weight, italic: italic, widthTrait: widthTrait),
        ]
        if smallCaps {
            attrs[kCTFontFeatureSettingsAttribute as String] = [
                [
                    kCTFontFeatureTypeIdentifierKey as String: kLowerCaseType,
                    kCTFontFeatureSelectorIdentifierKey as String: kLowerCaseSmallCapsSelector,
                ]
            ]
        }
        return CTFontDescriptorCreateWithAttributes(attrs as CFDictionary)
    }

    static func fontTraits(
        weight: Double, italic: Bool, widthTrait: Double?
    ) -> [String: Any] {
        var traits = [String: Any]()
        traits[kCTFontWeightTrait as String] = ctWeightTrait(forNumericWeight: weight)
        if let widthTrait {
            traits[kCTFontWidthTrait as String] = CGFloat(widthTrait)
        }
        if italic {
            traits[kCTFontSymbolicTrait as String] = CTFontSymbolicTraits.traitItalic.rawValue
        }
        return traits
    }

    static func ctWeightTrait(forNumericWeight weight: Double) -> CGFloat {
        switch weight {
        case ...199: -0.8
        case 200..<300: -0.6
        case 300..<400: -0.4
        case 400..<500: 0.0
        case 500..<600: 0.23
        case 600..<700: 0.3
        case 700..<800: 0.4
        case 800..<900: 0.56
        default: 0.62
        }
    }

    static func systemFontPostScriptName(
        weight: Double, italic: Bool, widthTrait: Double?, smallCaps: Bool
    ) -> String {
        guard let systemFont = CTFontCreateUIFontForLanguage(.system, 12.0, nil) else {
            return "Helvetica"
        }
        var attrs: [String: Any] = [
            kCTFontTraitsAttribute as String: fontTraits(
                weight: weight, italic: italic, widthTrait: widthTrait)
        ]
        if smallCaps {
            attrs[kCTFontFeatureSettingsAttribute as String] = [
                [
                    kCTFontFeatureTypeIdentifierKey as String: kLowerCaseType,
                    kCTFontFeatureSelectorIdentifierKey as String: kLowerCaseSmallCapsSelector,
                ]
            ]
        }
        let traitDescriptor = CTFontDescriptorCreateWithAttributes(attrs as CFDictionary)
        let styledFont = CTFontCreateCopyWithAttributes(systemFont, 12.0, nil, traitDescriptor)
        return CTFontCopyPostScriptName(styledFont) as String
    }

    /// Apply SVG 1.1 §10.10.2 font-size-adjust: scale the requested size
    /// so the resolved font's x-height matches `aspectRatio * adjustedSize`.
    /// Formula: `adjustedSize = requestedSize * (aspectRatio / (xHeight/requestedSize))`.
    static func adjustedSize(
        for fontName: String,
        requestedSize: Double,
        aspectRatio: Double?
    ) -> Double {
        guard let aspectRatio, aspectRatio > 0 else { return requestedSize }
        let font = CTFontCreateWithName(fontName as CFString, requestedSize, nil)
        let xHeight = CTFontGetXHeight(font)
        guard xHeight > 0 else { return requestedSize }
        let actualAspect = xHeight / requestedSize
        guard actualAspect > 0 else { return requestedSize }
        return requestedSize * (aspectRatio / actualAspect)
    }
}
