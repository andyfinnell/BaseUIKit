import Foundation
import CoreGraphics
import CoreText
import BaseKit

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class CanvasText<ID: Hashable & Sendable> {
    let id: ID
    var didDrawRect: CGRect = .zero
    var layer: Layer<ID> {
        didSet {
            updateFromLayer()
        }
    }
    
    weak var canvas: CanvasDatabase<ID>?
    
    var transform: Transform {
        didSet {
            if oldValue != transform {
                invalidate()
            }
        }
    }
    var opacity: Double {
        didSet {
            if oldValue != opacity {
                invalidate()
            }
        }
    }
    var blendMode: BlendMode {
        didSet {
            if oldValue != blendMode {
                invalidate()
            }
        }
    }
    var isVisible: Bool {
        didSet {
            if oldValue != isVisible {
                invalidate()
            }
        }
    }
    var decorations: [Decoration] {
        didSet {
            if oldValue != decorations {
                invalidate()
            }
        }
    }
    var autosize: Bool {
        didSet {
            if oldValue != autosize {
                invalidate()
            }
        }
    }
    var width: Double {
        didSet {
            if oldValue != width {
                invalidate()
            }
        }
    }
    var runs: [TextRun] {
        didSet {
            attributedStringCache = nil
            if oldValue != runs {
                invalidate()
            }
        }
    }
    
    private var framesetterCache: CTFramesetter?
    private var attributedStringCache: NSAttributedString?
    private var cgPathCache: CGPath?
    
    init(layer: TextLayer<ID>) {
        self.layer = .text(layer)
        self.id = layer.id
        self.transform = layer.transform
        self.opacity = layer.opacity
        self.blendMode = layer.blendMode
        self.isVisible = layer.isVisible
        self.decorations = layer.decorations
        self.runs = layer.runs
        self.autosize = layer.autosize
        self.width = layer.width
    }
    
    struct RenderedTextRun {
        let text: String
        let attributes: [TextRun.Attribute]
        let bounds: CGRect
    }
    
    func renderedTextRuns(in context: CGContext) -> [RenderedTextRun] {
        // Create the frame
        let bounds = framesetterBounds
        let boundsPath = CGMutablePath(rect: bounds, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter,
                                             CFRange(location: 0, length: 0),
                                             boundsPath,
                                             nil)
        
        // Iterate the lines
        let frameOrigin = CGPoint.zero
        let lines = frame.lines
        guard !lines.isEmpty else {
            return []
        }
        
        var renderedRuns = [RenderedTextRun]()
        for (line, lineOrigin) in zip(lines, frame.lineOrigins) {
            var runOrigin = frameOrigin + lineOrigin
            for run in line.runs {
                let typographicBounds = run.typographicBounds
                let typographicRunBounds = CGRect(x: runOrigin.x,
                                       y: runOrigin.y,
                                       width: typographicBounds.width,
                                       height: typographicBounds.ascent + typographicBounds.descent)
                let renderedRun = RenderedTextRun(
                    text: substring(from: run.range),
                    attributes: attributes(from: run.attributes),
                    bounds: typographicRunBounds
                )
                runOrigin.x += typographicBounds.width
                renderedRuns.append(renderedRun)
            }
        }

        return renderedRuns
    }
    
    var bezierPath: BezierPath {
        BezierPath(cgPath)
    }
}

extension CanvasText: CanvasObjectDrawable {
    func invalidate() {
        canvas?.invalidate(self)
    }
    
    var willDrawRect: CGRect {
        globalEffectiveBounds
    }
    
    var structureBounds: CGRect {
        if runs.isEmpty  {
            let font = CTFontCreateWithName("Helvetica" as CFString, 12, nil)
            let lineHeight = ceil(CTFontGetAscent(font)) + ceil(CTFontGetDescent(font))
            let width = autosize ? 15.0 : self.width
            return CGRect(x: 0, y: 0, width: width, height: lineHeight)
        } else {
            return framesetterBounds
        }
    }

    func drawSelf(_ rect: CGRect, into context: CGContext, atScale scale: CGFloat) {
        guard !runs.isEmpty else {
            return
        }
        
        let bounds = structureBounds
        let path = cgPath
        
        for decoration in decorations {
            setPath(path, with: bounds, in: context)
            decoration.render(into: context, atScale: scale)
        }
    }
    
    func hitTest(_ location: CGPoint) -> Bool {
        cgPath.contains(location)
    }
    
    func intersects(_ rect: CGRect) -> Bool {
        cgPath.intersects(CGPath(rect: rect, transform: nil))
    }
    
    func contained(by rect: CGRect) -> Bool {
        rect.contains(cgPath.boundingBoxOfPath)
    }

    var structurePath: BezierPath {
        BezierPath(cgPath)
    }
}

private extension CanvasText {
    func updateFromLayer() {
        guard case let .text(textLayer) = layer else {
            return
        }
        update(with: textLayer)
    }
    
    func update(with layer: TextLayer<ID>) {
        self.transform = layer.transform
        self.opacity = layer.opacity
        self.blendMode = layer.blendMode
        self.decorations = layer.decorations
        self.runs = layer.runs
        self.autosize = layer.autosize
        self.width = layer.width
    }

    var attributedString: NSAttributedString {
        if let attributedStringCache {
            return attributedStringCache
        }
        
        let attributedString = runs.reduce(into: NSMutableAttributedString()) { partial, run in
            partial.append(self.attributedString(from: run))
        }
        
        if let lastCh = attributedString.string.last, lastCh == "\n" {
            attributedString.append(NSAttributedString(string: " "))
        }
        
        attributedStringCache = attributedString
        return attributedString
    }
    
    func attributedString(from run: TextRun) -> NSAttributedString {
        NSAttributedString(string: run.text, attributes: attributes(from: run.attributes))
    }
    
    func attributes(from attributes: [TextRun.Attribute]) -> [NSAttributedString.Key: Any] {
        var fontName = "Helvetica"
        var fontSize: CGFloat = 12.0
        var textAlignment: NSTextAlignment?
        
        for attribute in attributes {
            switch attribute {
            case let .fontName(name):
                fontName = name
            case let .fontSize(size):
                fontSize = size
            case let .textAlign(align):
                textAlignment = align.toNative
            }
        }
        
        var attributeDictionary = [NSAttributedString.Key: Any]()
        attributeDictionary[.font] = Font(name: fontName, size: fontSize).native
        
        if let textAlignment {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = textAlignment
            attributeDictionary[.paragraphStyle] = paragraphStyle
        }
        
        return attributeDictionary
    }
    
    func attributes(from attributeDictionary: [NSAttributedString.Key: Any]) -> [TextRun.Attribute] {
        var attributes = [TextRun.Attribute]()
        if let font = attributeDictionary[.font] as? NativeFont {
            attributes.append(.fontName(font.fontName))
            attributes.append(.fontSize(font.pointSize))
        }
        if let paragraphStyle = attributeDictionary[.paragraphStyle] as? NSParagraphStyle {
            attributes.append(.textAlign(TextAlignment(native: paragraphStyle.alignment)))
        }
        return attributes
    }
    
    func substring(from range: CFRange) -> String {
        let substring = attributedString.attributedSubstring(from: NSRange(location: range.location, length: range.length))
        return substring.string
    }
    
    var framesetter: CTFramesetter {
        if let framesetterCache {
            return framesetterCache
        }
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        framesetterCache = framesetter
        return framesetter
    }
    
    var cgPath: CGPath {
        if let cgPathCache {
            return cgPathCache
        }
        // Create the frame
        let bounds = framesetterBounds
        let boundsPath = CGMutablePath(rect: bounds, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter,
                                             CFRange(location: 0, length: 0),
                                             boundsPath,
                                             nil)
        
        // Iterate the lines
        let finalPath = CGMutablePath()
        let frameOrigin = CGPoint.zero
        let lines = frame.lines
        
        guard !lines.isEmpty else {
            return finalPath
        }
                
        for (line, lineOrigin) in zip(lines, frame.lineOrigins) {
            for run in line.runs {
                let coreFont = run.font as CTFont
                for (glyph, position) in zip(run.glyphs, run.positions) {
                    let finalPosition = frameOrigin + lineOrigin + position
                    var glyphTransform = CGAffineTransform(translationX: finalPosition.x,
                                                           y: finalPosition.y)
                    guard let glyphPath = CTFontCreatePathForGlyph(coreFont,
                                                             glyph,
                                                                   &glyphTransform) else {
                        continue
                    }
                    finalPath.addPath(glyphPath)
                }
            }
        }
        
        cgPathCache = finalPath
        
        return finalPath
    }
    
    var framesetterBounds: CGRect {
        var constraints = CGSize(width: width, height: .greatestFiniteMagnitude)
        if autosize {
            constraints.width = .greatestFiniteMagnitude
        }
        
        let frameSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter,
                                                                     CFRange(location: 0, length: 0),
                                                                     nil,
                                                                     constraints,
                                                                     nil)
        
        var bounds = CGRect(x: 0, y: 0, width: frameSize.width, height: frameSize.height)
        if !autosize {
            bounds.size.width = width
        }
        return bounds
    }
        
    var effectiveBounds: CGRect {
        decorations.effectiveBounds(for: structureBounds)
    }
    
    var globalEffectiveBounds: CGRect {
        transform.apply(to: effectiveBounds)
    }
    
    func setPath(_ path: CGPath, with bounds: CGRect, in context: CGContext) {
        context.saveGState()
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        context.addPath(path)
        context.restoreGState()
    }
}
