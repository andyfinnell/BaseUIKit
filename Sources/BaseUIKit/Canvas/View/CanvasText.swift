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
        let effectiveTransform = Self.applyBaselineOffset(layer.baseline, to: layer.transform, runs: layer.runs)
        self.memberData = Mutex(
            MemberData(
                didDrawRect: .zero,
                layer: .text(layer),
                transform: effectiveTransform,
                opacity: layer.opacity,
                blendMode: layer.blendMode,
                isVisible: layer.isVisible,
                decorations: layer.decorations,
                autosize: layer.autosize,
                width: layer.width,
                runs: layer.runs,
                baseline: layer.baseline,
                textDecorationLines: layer.textDecorationLines,
                filter: layer.filter
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

    func draw(_ rect: CGRect, into context: CGContext, atScale scale: CGFloat, renderingCache: RenderingCache?) {
        memberData.withLock {
            locked_draw(&$0, in: rect, into: context, atScale: scale, renderingCache: renderingCache)
        }
    }

    func hitTest(_ location: CGPoint) -> Bool {
        memberData.withLock {
            let bounds = locked_structureBounds(&$0)
            let affineTransform = $0.transform.toCG
            let contentBounds = bounds.applying(affineTransform)
            return contentBounds.contains(location)
        }
    }

    func intersects(_ rect: CGRect) -> Bool {
        memberData.withLock {
            let bounds = locked_structureBounds(&$0)
            let affineTransform = $0.transform.toCG
            let contentBounds = bounds.applying(affineTransform)
            return contentBounds.intersects(rect)
        }
    }

    func contained(by rect: CGRect) -> Bool {
        memberData.withLock {
            let bounds = locked_structureBounds(&$0)
            let affineTransform = $0.transform.toCG
            let contentBounds = bounds.applying(affineTransform)
            return rect.contains(contentBounds)
        }
    }

    var structurePath: BezierPath {
        memberData.withLock {
            var path = BezierPath(locked_cgPath(&$0))
            path.transform($0.transform)
            return path
        }
    }

    var typographicBounds: CGRect? {
        memberData.withLock {
            let localBounds = locked_structureBounds(&$0)
            return localBounds.applying($0.transform.toCG)
        }
    }

    func textIndex(at point: CGPoint) -> TextPosition? {
        memberData.withLock {
            locked_textIndex(&$0, at: point)
        }
    }

    func textRects(for range: TextRange) -> [CGRect]? {
        memberData.withLock {
            locked_textRects(&$0, for: range)
        }
    }

    func navigateText(_ navigation: TextNavigation, from position: TextPosition) -> TextPosition? {
        memberData.withLock {
            coreText.navigateText(
                navigation,
                from: position,
                fromRuns: $0.runs,
                autosize: $0.autosize,
                width: $0.width
            )
        }
    }

    func caretRect(at position: TextPosition) -> CGRect? {
        memberData.withLock {
            locked_caretRect(&$0, at: position)
        }
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
        var baseline: TextBaseline
        var textDecorationLines: TextDecorationLine
        var filter: FilterLayer?
    }

    func locked_textIndex(_ memberData: inout MemberData, at point: CGPoint) -> TextPosition? {
        guard let inverseTransform = memberData.transform.inverted() else {
            return nil
        }
        
        // Transform from content space into the text's local space
        let localPoint = inverseTransform.applying(to: Point(point)).toCG
        
        // Flip from top-down to CoreText bottom-up coordinates
        let bounds = locked_structureBounds(&memberData)
        let coreTextPoint = CGPoint(x: localPoint.x, y: bounds.height - localPoint.y)
        
        return coreText.closestStringIndex(
            at: coreTextPoint,
            fromRuns: memberData.runs,
            autosize: memberData.autosize,
            width: memberData.width
        )
    }

    func locked_textRects(_ memberData: inout MemberData, for range: TextRange) -> [CGRect] {
        let bounds = locked_structureBounds(&memberData)
        let affineTransform = memberData.transform.toCG
        let coreTextRects = coreText.textRects(
            for: range,
            fromRuns: memberData.runs,
            autosize: memberData.autosize,
            width: memberData.width
        )

        // CoreText rects are in bottom-up coordinates; flip to top-down,
        // then transform from local space to content space
        return coreTextRects.map { rect in
            CGRect(
                x: rect.origin.x,
                y: bounds.height - rect.origin.y - rect.height,
                width: rect.width,
                height: rect.height
            ).applying(affineTransform)
        }
    }

    func locked_caretRect(_ memberData: inout MemberData, at position: TextPosition) -> CGRect {
        let bounds = locked_structureBounds(&memberData)
        let affineTransform = memberData.transform.toCG
        let coreTextRect = coreText.caretRect(
            at: position,
            fromRuns: memberData.runs,
            autosize: memberData.autosize,
            width: memberData.width
        )

        // CoreText rect is in bottom-up coordinates; flip to top-down,
        // then transform from local space to content space
        return CGRect(
            x: coreTextRect.origin.x,
            y: bounds.height - coreTextRect.origin.y - coreTextRect.height,
            width: coreTextRect.width,
            height: coreTextRect.height
        ).applying(affineTransform)
    }

    func locked_draw(_ memberData: inout MemberData, in rect: CGRect, into context: CGContext, atScale scale: CGFloat, renderingCache: RenderingCache?) {
        guard locked_willDrawRect(&memberData).intersects(rect) else {
            return
        }

        memberData.didDrawRect = locked_willDrawRect(&memberData)

        guard memberData.isVisible else {
            return
        }

        context.saveGState()

        let needsTransparencyLayer = memberData.opacity < 1.0 || memberData.blendMode != .normal
        if needsTransparencyLayer {
            context.setAlpha(memberData.opacity)
            context.setBlendMode(memberData.blendMode.toCG)
            context.beginTransparencyLayer(auxiliaryInfo: nil)
        }

        let affineTransform = memberData.transform.toCG
        context.concatenate(affineTransform)

        if let filter = memberData.filter {
            filter.drawFiltered(into: context, scale: scale, renderingCache: renderingCache) { targetContext in
                locked_drawSelf(&memberData, in: rect, into: targetContext, atScale: scale, renderingCache: renderingCache)
            }
        } else {
            locked_drawSelf(&memberData, in: rect, into: context, atScale: scale, renderingCache: renderingCache)
        }

        if needsTransparencyLayer {
            context.endTransparencyLayer()
        }
        context.restoreGState()
    }

    func locked_drawSelf(_ memberData: inout MemberData, in rect: CGRect, into context: CGContext, atScale scale: CGFloat, renderingCache: RenderingCache?) {
        let bounds = locked_structureBounds(&memberData)

        if !memberData.runs.isEmpty {
            let path = locked_cgPath(&memberData)
            for decoration in memberData.decorations {
                setPath(path, with: bounds, in: context)
                decoration.render(into: context, atScale: scale, renderingCache: renderingCache)
            }

            if !memberData.textDecorationLines.isEmpty {
                let linePath = coreText.textDecorationPath(
                    memberData.textDecorationLines,
                    fromRuns: memberData.runs,
                    autosize: memberData.autosize,
                    width: memberData.width
                )
                for decoration in memberData.decorations {
                    setPath(linePath.cgPath, with: bounds, in: context)
                    decoration.render(into: context, atScale: scale, renderingCache: renderingCache)
                }
            }
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

        // Recompute effective transform when transform, baseline, or runs change
        let runsChanged = memberData.runs != layer.runs
        if memberData.baseline != layer.baseline || runsChanged {
            memberData.baseline = layer.baseline
        }
        if runsChanged {
            memberData.runs = layer.runs
            coreText.clear()
            didChange = true
        }
        let effectiveTransform = Self.applyBaselineOffset(layer.baseline, to: layer.transform, runs: layer.runs)
        if memberData.transform != effectiveTransform {
            memberData.transform = effectiveTransform
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
        if memberData.isVisible != layer.isVisible {
            memberData.isVisible = layer.isVisible
            didChange = true
        }
        if memberData.decorations != layer.decorations {
            memberData.decorations = layer.decorations
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
        if memberData.textDecorationLines != layer.textDecorationLines {
            memberData.textDecorationLines = layer.textDecorationLines
            didChange = true
        }
        if memberData.filter != layer.filter {
            memberData.filter = layer.filter
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

    static func applyBaselineOffset(_ baseline: TextBaseline, to transform: Transform, runs: [TextRun]) -> Transform {
        let offset = computeBaselineOffset(baseline, runs: runs)
        guard offset != 0 else { return transform }
        return transform.concatenating(Transform(translateX: 0, y: offset))
    }

    static func computeBaselineOffset(_ baseline: TextBaseline, runs: [TextRun]) -> Double {
        var fontName = "Times"
        var fontSize: CGFloat = 16.0
        if let firstRun = runs.first {
            for attribute in firstRun.attributes {
                switch attribute {
                case let .fontName(name): fontName = name
                case let .fontSize(size): fontSize = size
                case .textAlign: break
                }
            }
        }

        let ctFont = CTFontCreateWithName(fontName as CFString, fontSize, nil)
        let ascent = Double(CTFontGetAscent(ctFont))
        let descent = Double(CTFontGetDescent(ctFont))
        let xHeight = Double(CTFontGetXHeight(ctFont))
        let capHeight = Double(CTFontGetCapHeight(ctFont))

        // The offset shifts from the SVG y-coordinate (the specified baseline position)
        // to the top of the text frame. CoreText renders with the frame origin at the
        // top-left, so we translate y upward by the distance from baseline to frame top.
        return switch baseline {
        case .alphabetic:
            -ascent
        case .top:
            0
        case .bottom:
            -(ascent + descent)
        case .middle:
            -ascent + xHeight / 2.0
        case .central:
            -(ascent + descent) / 2.0
        case .hanging:
            -(ascent - capHeight)
        case .mathematical:
            -ascent + capHeight / 2.0
        }
    }
}

// MARK: - CoreText

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

    func textRects(for range: TextRange, fromRuns runs: [TextRun], autosize: Bool, width: CGFloat) -> [CGRect] {
        queue.sync {
            queued_textRects(for: range, fromRuns: runs, autosize: autosize, width: width)
        }
    }

    func caretRect(at position: TextPosition, fromRuns runs: [TextRun], autosize: Bool, width: CGFloat) -> CGRect {
        queue.sync {
            queued_caretRect(at: position, fromRuns: runs, autosize: autosize, width: width)
        }
    }

    func closestStringIndex(at point: CGPoint, fromRuns runs: [TextRun], autosize: Bool, width: CGFloat) -> TextPosition {
        queue.sync {
            queued_closestStringIndex(at: point, fromRuns: runs, autosize: autosize, width: width)
        }
    }

    func navigateText(_ navigation: TextNavigation, from position: TextPosition, fromRuns runs: [TextRun], autosize: Bool, width: CGFloat) -> TextPosition {
        queue.sync {
            queued_navigateText(navigation, from: position, fromRuns: runs, autosize: autosize, width: width)
        }
    }

    func textDecorationPath(_ lines: TextDecorationLine, fromRuns runs: [TextRun], autosize: Bool, width: CGFloat) -> BezierPath {
        queue.sync {
            BezierPath(queued_textDecorationPath(lines, fromRuns: runs, autosize: autosize, width: width))
        }
    }
}

private extension ProtectedCoreText {
    func queued_structureBounds(fromRuns runs: [TextRun], autosize: Bool, width: CGFloat) -> CGRect {
        if runs.isEmpty  {
            let font = CTFontCreateWithName("Times" as CFString, 16, nil)
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

    func queued_frame(fromRuns runs: [TextRun], autosize: Bool, width: CGFloat) -> CTFrame {
        let bounds = queued_framesetterBounds(fromRuns: runs, autosize: autosize, width: width)
        let boundsPath = CGMutablePath(rect: bounds, transform: nil)
        return CTFramesetterCreateFrame(
            queued_framesetter(fromRuns: runs),
            CFRange(location: 0, length: 0),
            boundsPath,
            nil
        )
    }

    func queued_textRects(for range: TextRange, fromRuns runs: [TextRun], autosize: Bool, width: CGFloat) -> [CGRect] {
        let frame = queued_frame(fromRuns: runs, autosize: autosize, width: width)
        let lines = frame.lines
        let lineOrigins = frame.lineOrigins
        guard !lines.isEmpty else {
            return []
        }

        let selStart = range.start.utf16Offset
        let selEnd = range.end.utf16Offset

        var rects = [CGRect]()
        for (line, lineOrigin) in zip(lines, lineOrigins) {
            let lineRange = CTLineGetStringRange(line)
            let lineStart = lineRange.location
            let lineEnd = lineRange.location + lineRange.length

            guard selEnd > lineStart && selStart < lineEnd else {
                continue
            }

            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            var leading: CGFloat = 0
            CTLineGetTypographicBounds(line, &ascent, &descent, &leading)

            let clampedStart = max(selStart, lineStart)
            let clampedEnd = min(selEnd, lineEnd)
            let startX = CTLineGetOffsetForStringIndex(line, clampedStart, nil)
            let endX = CTLineGetOffsetForStringIndex(line, clampedEnd, nil)

            let rect = CGRect(
                x: lineOrigin.x + startX,
                y: lineOrigin.y - descent,
                width: endX - startX,
                height: ascent + descent
            )
            rects.append(rect)
        }

        return rects
    }

    func queued_caretRect(at position: TextPosition, fromRuns runs: [TextRun], autosize: Bool, width: CGFloat) -> CGRect {
        let frame = queued_frame(fromRuns: runs, autosize: autosize, width: width)
        let lines = frame.lines
        let lineOrigins = frame.lineOrigins
        let caretWidth: CGFloat = 1.0
        let index = position.utf16Offset

        guard !lines.isEmpty else {
            let bounds = queued_structureBounds(fromRuns: runs, autosize: autosize, width: width)
            return CGRect(x: 0, y: 0, width: caretWidth, height: bounds.height)
        }

        // Find the line containing the position
        for (line, lineOrigin) in zip(lines, lineOrigins) {
            let lineRange = CTLineGetStringRange(line)
            let lineStart = lineRange.location
            let lineEnd = lineRange.location + lineRange.length

            // Position is within this line, or at the end of the last character
            guard index >= lineStart && index <= lineEnd else {
                continue
            }

            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            var leading: CGFloat = 0
            CTLineGetTypographicBounds(line, &ascent, &descent, &leading)

            let xOffset = CTLineGetOffsetForStringIndex(line, index, nil)
            return CGRect(
                x: lineOrigin.x + xOffset - caretWidth / 2.0,
                y: lineOrigin.y - descent,
                width: caretWidth,
                height: ascent + descent
            )
        }

        // Fallback: position past the end of all text, use last line
        let lastLine = lines[lines.count - 1]
        let lastOrigin = lineOrigins[lineOrigins.count - 1]
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        CTLineGetTypographicBounds(lastLine, &ascent, &descent, &leading)
        let xOffset = CTLineGetOffsetForStringIndex(lastLine, index, nil)
        return CGRect(
            x: lastOrigin.x + xOffset - caretWidth / 2.0,
            y: lastOrigin.y - descent,
            width: caretWidth,
            height: ascent + descent
        )
    }

    func queued_closestStringIndex(at point: CGPoint, fromRuns runs: [TextRun], autosize: Bool, width: CGFloat) -> TextPosition {
        let frame = queued_frame(fromRuns: runs, autosize: autosize, width: width)
        let lines = frame.lines
        let lineOrigins = frame.lineOrigins

        guard !lines.isEmpty else {
            return TextPosition(utf16Offset:0)
        }

        // Find the closest line by vertical distance to the point
        var closestLine = lines[0]
        var closestLineOrigin = lineOrigins[0]
        var closestDistance = CGFloat.greatestFiniteMagnitude

        for (line, lineOrigin) in zip(lines, lineOrigins) {
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            CTLineGetTypographicBounds(line, &ascent, &descent, nil)

            let lineTop = lineOrigin.y + ascent
            let lineBottom = lineOrigin.y - descent

            let distance: CGFloat
            if point.y >= lineBottom && point.y <= lineTop {
                distance = 0
            } else {
                distance = min(abs(point.y - lineTop), abs(point.y - lineBottom))
            }

            if distance < closestDistance {
                closestDistance = distance
                closestLine = line
                closestLineOrigin = lineOrigin
            }
        }

        let localX = point.x - closestLineOrigin.x
        return TextPosition(utf16Offset:CTLineGetStringIndexForPosition(closestLine, CGPoint(x: localX, y: 0)))
    }

    func queued_navigateText(_ navigation: TextNavigation, from position: TextPosition, fromRuns runs: [TextRun], autosize: Bool, width: CGFloat) -> TextPosition {
        let frame = queued_frame(fromRuns: runs, autosize: autosize, width: width)
        let lines = frame.lines
        let lineOrigins = frame.lineOrigins
        let index = position.utf16Offset
        let textLength = queued_attributedString(fromRuns: runs).length

        guard !lines.isEmpty else {
            return TextPosition(utf16Offset:0)
        }

        switch navigation {
        case .left:
            return TextPosition(utf16Offset:max(index - 1, 0))

        case .right:
            return TextPosition(utf16Offset:min(index + 1, textLength))

        case .wordLeft:
            guard index > 0 else { return TextPosition(utf16Offset:0) }
            let string = queued_attributedString(fromRuns: runs).string as NSString
            var wordStart = index
            string.enumerateSubstrings(
                in: NSRange(location: 0, length: index),
                options: [.byWords, .reverse, .substringNotRequired]
            ) { _, range, _, stop in
                wordStart = range.location
                stop.pointee = true
            }
            return TextPosition(utf16Offset:wordStart)

        case .wordRight:
            guard index < textLength else { return TextPosition(utf16Offset:textLength) }
            let string = queued_attributedString(fromRuns: runs).string as NSString
            var wordEnd = textLength
            string.enumerateSubstrings(
                in: NSRange(location: index, length: textLength - index),
                options: [.byWords, .substringNotRequired]
            ) { _, range, _, stop in
                let end = range.location + range.length
                if end > index {
                    wordEnd = end
                    stop.pointee = true
                }
            }
            return TextPosition(utf16Offset:wordEnd)

        case .beginningOfParagraph:
            guard textLength > 0 else { return TextPosition(utf16Offset:0) }
            let string = queued_attributedString(fromRuns: runs).string as NSString
            let clampedIndex = min(index, textLength - 1)
            let nsRange = string.paragraphRange(for: NSRange(location: clampedIndex, length: 0))
            return TextPosition(utf16Offset:nsRange.location)

        case .endOfParagraph:
            guard textLength > 0 else { return TextPosition(utf16Offset:0) }
            let string = queued_attributedString(fromRuns: runs).string as NSString
            let clampedIndex = min(index, textLength - 1)
            let nsRange = string.paragraphRange(for: NSRange(location: clampedIndex, length: 0))
            return TextPosition(utf16Offset:nsRange.location + nsRange.length)

        case .beginningOfLine:
            let lineIndex = queued_lineIndex(containing: index, in: lines)
            let lineRange = CTLineGetStringRange(lines[lineIndex])
            return TextPosition(utf16Offset:lineRange.location)

        case .endOfLine:
            let lineIndex = queued_lineIndex(containing: index, in: lines)
            let lineRange = CTLineGetStringRange(lines[lineIndex])
            return TextPosition(utf16Offset:lineRange.location + lineRange.length)

        case .up:
            let lineIndex = queued_lineIndex(containing: index, in: lines)
            guard lineIndex > 0 else {
                return TextPosition(utf16Offset:0)
            }
            let xOffset = CTLineGetOffsetForStringIndex(lines[lineIndex], index, nil)
            let localX = lineOrigins[lineIndex].x + xOffset - lineOrigins[lineIndex - 1].x
            return TextPosition(utf16Offset:CTLineGetStringIndexForPosition(lines[lineIndex - 1], CGPoint(x: localX, y: 0)))

        case .down:
            let lineIndex = queued_lineIndex(containing: index, in: lines)
            guard lineIndex < lines.count - 1 else {
                return TextPosition(utf16Offset:textLength)
            }
            let xOffset = CTLineGetOffsetForStringIndex(lines[lineIndex], index, nil)
            let localX = lineOrigins[lineIndex].x + xOffset - lineOrigins[lineIndex + 1].x
            return TextPosition(utf16Offset:CTLineGetStringIndexForPosition(lines[lineIndex + 1], CGPoint(x: localX, y: 0)))

        case .begin:
            return TextPosition(utf16Offset:0)

        case .end:
            return TextPosition(utf16Offset:textLength)
        }
    }

    func queued_lineIndex(containing index: Int, in lines: [CTLine]) -> Int {
        for (i, line) in lines.enumerated() {
            let lineRange = CTLineGetStringRange(line)
            let lineStart = lineRange.location
            let lineEnd = lineRange.location + lineRange.length
            if index >= lineStart && index <= lineEnd {
                return i
            }
        }
        return lines.count - 1
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

    func queued_textDecorationPath(_ lines: TextDecorationLine, fromRuns runs: [TextRun], autosize: Bool, width: CGFloat) -> CGPath {
        let frame = queued_frame(fromRuns: runs, autosize: autosize, width: width)
        let ctLines = frame.lines
        let lineOrigins = frame.lineOrigins
        let path = CGMutablePath()

        guard !ctLines.isEmpty else { return path }

        let frameOrigin = CGPoint.zero
        for (line, lineOrigin) in zip(ctLines, lineOrigins) {
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            var leading: CGFloat = 0
            let lineWidth = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))

            // Get font metrics from the first run
            guard let firstRun = line.runs.first else { continue }
            let font = firstRun.font as CTFont
            let underlinePosition = CTFontGetUnderlinePosition(font)
            let underlineThickness = max(CTFontGetUnderlineThickness(font), 1.0)
            let xHeight = CTFontGetXHeight(font)

            let originX = frameOrigin.x + lineOrigin.x
            let baselineY = frameOrigin.y + lineOrigin.y

            if lines.contains(.underline) {
                let y = baselineY + underlinePosition - underlineThickness / 2.0
                path.addRect(CGRect(x: originX, y: y, width: lineWidth, height: underlineThickness))
            }

            if lines.contains(.overline) {
                let y = baselineY + ascent - underlineThickness / 2.0
                path.addRect(CGRect(x: originX, y: y, width: lineWidth, height: underlineThickness))
            }

            if lines.contains(.lineThrough) {
                let y = baselineY + xHeight / 2.0 - underlineThickness / 2.0
                path.addRect(CGRect(x: originX, y: y, width: lineWidth, height: underlineThickness))
            }
        }

        return path
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
        var fontName = "Times"
        var fontSize: CGFloat = 16.0
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
