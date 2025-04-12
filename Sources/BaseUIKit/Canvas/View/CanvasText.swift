import Foundation
import CoreGraphics
import CoreText
import BaseKit
import Synchronization

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

struct RenderedTextRun: Hashable, Sendable {
    let text: String
    let attributes: [TextRun.Attribute]
    let bounds: CGRect
}

final class CanvasText<ID: Hashable & Sendable>: Sendable {
    let id: ID
    private let memberData: Mutex<MemberData>
    private let coreText = ProtectedCoreText()

    var didDrawRect: CGRect { memberData.withLock { $0.didDrawRect } }
    
    var layer: Layer<ID> {
        memberData.withLock { $0.layer }
    }
                
    init(layer: TextLayer<ID>) {
        self.id = layer.id
        self.memberData = Mutex(
            MemberData(
                didDrawRect: .zero,
                layer: .text(layer),
                transform: layer.transform,
                opacity: layer.opacity,
                blendMode: layer.blendMode,
                isVisible: layer.isVisible,
                decorations: layer.decorations,
                autosize: layer.autosize,
                width: layer.width,
                runs: layer.runs
            )
        )
    }
    
}


extension CanvasText: CanvasObject {
    func updateLayer(_ layer: Layer<ID>) -> Set<CanvasInvalidation> {
        guard case let .text(textLayer) = layer else {
            return Set()
        }
        return memberData.withLock {
            locked_update(&$0, with: textLayer)
        }
    }
    
    var willDrawRect: CGRect {
        memberData.withLock {
            locked_willDrawRect(&$0)
        }
    }
    
    func draw(_ rect: CGRect, into context: CGContext, atScale scale: CGFloat) {
        memberData.withLock {
            locked_draw(&$0, in: rect, into: context, atScale: scale)
        }
    }
    
    func hitTest(_ location: CGPoint) -> Bool {
        let path = memberData.withLock {
            locked_cgPath(&$0)
        }
        return path.contains(location)
    }
    
    func intersects(_ rect: CGRect) -> Bool {
        let path = memberData.withLock {
            locked_cgPath(&$0)
        }
        return path.intersects(CGPath(rect: rect, transform: nil))
    }
    
    func contained(by rect: CGRect) -> Bool {
        let path = memberData.withLock {
            locked_cgPath(&$0)
        }
        return rect.contains(path.boundingBoxOfPath)
    }

    var structurePath: BezierPath {
        let path = memberData.withLock {
            locked_cgPath(&$0)
        }
        return BezierPath(path)
    }
}

private extension CanvasText {
    struct MemberData: Sendable {
        var didDrawRect: CGRect
        var layer: Layer<ID>
        var transform: Transform
        var opacity: Double
        var blendMode: BlendMode
        var isVisible: Bool
        var decorations: [Decoration]
        var autosize: Bool
        var width: Double
        var runs: [TextRun]
    }
        
    func locked_draw(_ memberData: inout MemberData, in rect: CGRect, into context: CGContext, atScale scale: CGFloat) {
        guard locked_willDrawRect(&memberData).intersects(rect) else {
            return
        }
        
        memberData.didDrawRect = locked_willDrawRect(&memberData)
        
        guard memberData.isVisible else {
            return
        }
        
        context.saveGState()
        
        context.setAlpha(memberData.opacity)
        context.setBlendMode(memberData.blendMode.toCG)
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        
        let affineTransform = memberData.transform.toCG
        context.concatenate(affineTransform)
        
        locked_drawSelf(&memberData, in: rect, into: context, atScale: scale)
        
        context.endTransparencyLayer()
        context.restoreGState()
    }

    func locked_drawSelf(_ memberData: inout MemberData, in rect: CGRect, into context: CGContext, atScale scale: CGFloat) {
        guard !memberData.runs.isEmpty else {
            return
        }
        
        let bounds = locked_structureBounds(&memberData)
        let path = locked_cgPath(&memberData)
                
        for decoration in memberData.decorations {
            setPath(path, with: bounds, in: context)
            decoration.render(into: context, atScale: scale)
        }
    }

    func locked_structureBounds(_ memberData: inout MemberData) -> CGRect {
        coreText.structureBounds(
            fromRuns: memberData.runs,
            autosize: memberData.autosize,
            width: memberData.width
        )
    }
    
    func locked_cgPath(_ memberData: inout MemberData) -> CGPath {
        coreText.bezierPath(
            fromRuns: memberData.runs,
            autosize: memberData.autosize,
            width: memberData.width
        ).cgPath
    }
    
    func locked_update(
        _ memberData: inout MemberData,
        with layer: TextLayer<ID>
    ) -> Set<CanvasInvalidation> {
        var didChange = false
        memberData.layer = .text(layer)
        if memberData.transform != layer.transform {
            memberData.transform = layer.transform
            didChange = true
        }
        if memberData.opacity != layer.opacity {
            memberData.opacity = layer.opacity
            didChange = true
        }
        if memberData.blendMode != layer.blendMode {
            memberData.blendMode = layer.blendMode
            didChange = true
        }
        if memberData.decorations != layer.decorations {
            memberData.decorations = layer.decorations
            didChange = true
        }
        if memberData.runs != layer.runs {
            memberData.runs = layer.runs
            coreText.clear()
            didChange = true
        }
        if memberData.autosize != layer.autosize {
            memberData.autosize = layer.autosize
            didChange = true
        }
        if memberData.width != layer.width {
            memberData.width = layer.width
            didChange = true
        }
        if didChange {
            return Set([.invalidateRect(memberData.didDrawRect), .invalidateRect(locked_willDrawRect(&memberData))])
        } else {
            return Set()
        }
    }

    func locked_effectiveBounds(_ memberData: inout MemberData) -> CGRect {
        memberData.decorations.effectiveBounds(for: locked_structureBounds(&memberData))
    }
    
    func locked_globalEffectiveBounds(_ memberData: inout MemberData) -> CGRect {
        memberData.transform.apply(to: locked_effectiveBounds(&memberData))
    }
    
    func locked_willDrawRect(_ memberData: inout MemberData) -> CGRect {
        locked_globalEffectiveBounds(&memberData)
    }
    
    func setPath(_ path: CGPath, with bounds: CGRect, in context: CGContext) {
        context.saveGState()
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        context.addPath(path)
        context.restoreGState()
    }
}

/// These all have to be accessed from the same work queue in order to be thread safe
private final class ProtectedCoreText: @unchecked Sendable {
    private var framesetterCache: CTFramesetter?
    private var attributedStringCache: NSAttributedString?
    private var cgPathCache: CGPath?
    private let queue = DispatchQueue(label: "ProtectedCoreText")
    
    init() {
    }
    
    func clear() {
        queue.sync {
            framesetterCache = nil
            attributedStringCache = nil
            cgPathCache = nil
        }
    }
    
    func structureBounds(fromRuns runs: [TextRun], autosize: Bool, width: CGFloat) -> CGRect {
        queue.sync {
            queued_structureBounds(fromRuns: runs, autosize: autosize, width: width)
        }
    }
    
    /// Use a BezierPath since it's Sendable across isolation contexts
    func bezierPath(fromRuns runs: [TextRun], autosize: Bool, width: CGFloat) -> BezierPath {
        queue.sync {
            let cgPath = queued_cgPath(fromRuns: runs, autosize: autosize, width: width)
            return BezierPath(cgPath)
        }
    }
}

private extension ProtectedCoreText {
    func queued_structureBounds(fromRuns runs: [TextRun], autosize: Bool, width: CGFloat) -> CGRect {
        if runs.isEmpty  {
            let font = CTFontCreateWithName("Helvetica" as CFString, 12, nil)
            let lineHeight = ceil(CTFontGetAscent(font)) + ceil(CTFontGetDescent(font))
            let width = autosize ? 15.0 : width
            return CGRect(x: 0, y: 0, width: width, height: lineHeight)
        } else {
            return queued_framesetterBounds(fromRuns: runs, autosize: autosize, width: width)
        }
    }

    func queued_framesetterBounds(fromRuns runs: [TextRun], autosize: Bool, width: CGFloat) -> CGRect {
        var constraints = CGSize(width: width, height: .greatestFiniteMagnitude)
        if autosize {
            constraints.width = .greatestFiniteMagnitude
        }
        
        let frameSize = CTFramesetterSuggestFrameSizeWithConstraints(
            queued_framesetter(fromRuns: runs),
            CFRange(location: 0, length: 0),
            nil,
            constraints,
            nil
        )
        
        var bounds = CGRect(x: 0, y: 0, width: frameSize.width, height: frameSize.height)
        if !autosize {
            bounds.size.width = width
        }
        return bounds
    }

    func queued_framesetter(fromRuns runs: [TextRun]) -> CTFramesetter {
        if let framesetterCache {
            return framesetterCache
        }
        let framesetter = CTFramesetterCreateWithAttributedString(queued_attributedString(fromRuns: runs))
        self.framesetterCache = framesetter
        return framesetter
    }

    func queued_renderedTextRuns(
        fromRuns runs: [TextRun],
        autosize: Bool,
        width: CGFloat,
        in context: CGContext
    ) -> [RenderedTextRun] {
        // Create the frame
        let bounds = queued_framesetterBounds(fromRuns: runs, autosize: autosize, width: width)
        let boundsPath = CGMutablePath(rect: bounds, transform: nil)
        let frame = CTFramesetterCreateFrame(
            queued_framesetter(fromRuns: runs),
            CFRange(location: 0, length: 0),
            boundsPath,
            nil
        )
        
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
                    text: queued_substring(fromRuns: runs, in: run.range),
                    attributes: queued_attributes(from: run.attributes),
                    bounds: typographicRunBounds
                )
                runOrigin.x += typographicBounds.width
                renderedRuns.append(renderedRun)
            }
        }

        return renderedRuns
    }

    func queued_substring(fromRuns runs: [TextRun], in range: CFRange) -> String {
        let substring = queued_attributedString(fromRuns: runs).attributedSubstring(from: NSRange(location: range.location, length: range.length))
        return substring.string
    }
        
    func queued_cgPath(fromRuns runs: [TextRun], autosize: Bool, width: CGFloat) -> CGPath {
        if let cgPathCache {
            return cgPathCache
        }
        // Create the frame
        let bounds = queued_framesetterBounds(fromRuns: runs, autosize: autosize, width: width)
        let boundsPath = CGMutablePath(rect: bounds, transform: nil)
        let frame = CTFramesetterCreateFrame(
            queued_framesetter(fromRuns: runs),
            CFRange(location: 0, length: 0),
            boundsPath,
            nil
        )
        
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
                    var glyphTransform = CGAffineTransform(
                        translationX: finalPosition.x,
                        y: finalPosition.y
                    )
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
    
    func queued_attributedString(fromRuns runs: [TextRun]) -> NSAttributedString {
        if let attributedStringCache {
            return attributedStringCache
        }
        
        let attributedString = runs.reduce(into: NSMutableAttributedString()) { partial, run in
            partial.append(queued_attributedString(from: run))
        }
        
        if let lastCh = attributedString.string.last, lastCh == "\n" {
            attributedString.append(NSAttributedString(string: " "))
        }
        
        self.attributedStringCache = attributedString
        
        return attributedString
    }
    
    func queued_attributedString(from run: TextRun) -> NSAttributedString {
        NSAttributedString(string: run.text, attributes: queued_attributes(from: run.attributes))
    }
    
    func queued_attributes(from attributes: [TextRun.Attribute]) -> [NSAttributedString.Key: Any] {
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
    
    func queued_attributes(from attributeDictionary: [NSAttributedString.Key: Any]) -> [TextRun.Attribute] {
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
}
