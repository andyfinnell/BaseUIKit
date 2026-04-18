import Foundation
import CoreGraphics
import CoreText
import ImageIO
import BaseKit
import Synchronization

final class CanvasImage<ID: Hashable & Sendable>: Sendable {
    let id: ID
    var didDrawRect: CGRect { memberData.withLock { $0.didDrawRect } }
    var layer: Layer<ID> {
        memberData.withLock { $0.layer }
    }
    private let memberData: Mutex<MemberData>
    
    init(layer: ImageLayer<ID>) {
        self.id = layer.id
        self.memberData = Mutex(
            MemberData(
                didDrawRect: .zero,
                layer: .image(layer),
                transform: layer.transform,
                opacity: layer.opacity,
                blendMode: layer.blendMode,
                isVisible: layer.isVisible,
                width: layer.width,
                height: layer.height,
                imageData: layer.imageData,
                sourceLabel: layer.sourceLabel,
                clipRect: layer.clipRect,
                filter: layer.filter,
                imageCache: nil
            )
        )
    }
}

extension CanvasImage: CanvasObject {    
    func updateLayer(_ layer: Layer<ID>) -> Set<CanvasInvalidation> {
        guard case let .image(imageLayer) = layer else {
            return Set()
        }
        return memberData.withLock {
            locked_update(&$0, with: imageLayer)
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
            locked_globalBounds(&$0).contains(location)
        }
    }
    
    func intersects(_ rect: CGRect) -> Bool {
        memberData.withLock {
            locked_globalBounds(&$0).intersects(rect)
        }
    }
    
    func contained(by rect: CGRect) -> Bool {
        memberData.withLock {
            rect.contains(locked_globalBounds(&$0))
        }
    }
    
    var structurePath: BezierPath {
        let globalBounds = memberData.withLock { locked_globalBounds(&$0) }
        return BezierPath(rect: Rect(globalBounds))
    }

    var typographicBounds: CGRect? { nil }

    var outlinePath: BezierPath { structurePath }
    
    func textIndex(at location: CGPoint) -> TextPosition? {
        nil
    }

    func textRects(for range: TextRange) -> [CGRect]? {
        nil
    }

    func navigateText(_ navigation: TextNavigation, from position: TextPosition) -> TextPosition? {
        nil
    }

    func caretRect(at position: TextPosition) -> CGRect? {
        nil
    }

    var transform: Transform {
        memberData.withLock { $0.transform }
    }

    func sampleColor(at canvasLocation: CGPoint) -> Color? {
        memberData.withLock { locked_sampleColor(&$0, at: canvasLocation) }
    }
}

private extension CanvasImage {
    struct MemberData {
        var didDrawRect: CGRect
        var layer: Layer<ID>
        var transform: Transform
        var opacity: Double
        var blendMode: BlendMode
        var isVisible: Bool
        var width: Double
        var height: Double
        var imageData: Data?
        var sourceLabel: String?
        var clipRect: Rect?
        var filter: FilterLayer?
        var imageCache: CGImage?
    }
    
    func locked_update(_ memberData: inout MemberData, with layer: ImageLayer<ID>) -> Set<CanvasInvalidation> {
        var didChange = false
        memberData.layer = .image(layer)
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
        if memberData.isVisible != layer.isVisible {
            memberData.isVisible = layer.isVisible
            didChange = true
        }
        if memberData.width != layer.width {
            memberData.width = layer.width
            didChange = true
        }
        if memberData.height != layer.height {
            memberData.height = layer.height
            didChange = true
        }
        if memberData.imageData != layer.imageData {
            memberData.imageData = layer.imageData
            memberData.imageCache = nil
            didChange = true
        }
        if memberData.sourceLabel != layer.sourceLabel {
            memberData.sourceLabel = layer.sourceLabel
            didChange = true
        }
        if memberData.clipRect != layer.clipRect {
            memberData.clipRect = layer.clipRect
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

    func locked_structureBounds(_ memberData: inout MemberData) -> CGRect {
        if let clipRect = memberData.clipRect {
            return clipRect.toCG
        }
        return CGRect(x: 0, y: 0, width: memberData.width, height: memberData.height)
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

        if let clipRect = memberData.clipRect {
            context.clip(to: [clipRect.toCG])
        }

        if let filter = memberData.filter {
            filter.drawFiltered(into: context, scale: scale, renderingCache: renderingCache) { targetContext in
                locked_drawSelf(&memberData, in: rect, into: targetContext, atScale: scale)
            }
        } else {
            locked_drawSelf(&memberData, in: rect, into: context, atScale: scale)
        }

        if needsTransparencyLayer {
            context.endTransparencyLayer()
        }
        context.restoreGState()
    }

    func locked_drawSelf(_ memberData: inout MemberData, in rect: CGRect, into context: CGContext, atScale scale: CGFloat) {
        let bounds = CGRect(x: 0, y: 0, width: memberData.width, height: memberData.height)

        if memberData.imageData != nil, let image = locked_image(&memberData) {
            // Flip the image (CGContext has flipped Y axis)
            context.translateBy(x: 0, y: bounds.height)
            context.scaleBy(x: 1, y: -1)
            context.draw(image, in: bounds)
        } else {
            locked_drawBrokenImagePlaceholder(&memberData, in: bounds, into: context)
        }
    }

    func locked_drawBrokenImagePlaceholder(_ memberData: inout MemberData, in bounds: CGRect, into context: CGContext) {
        let borderColor = CGColor(gray: 0.67, alpha: 1)
        let iconColor = CGColor(gray: 0.4, alpha: 1)
        let strokeWidth = max(1.0, min(bounds.width, bounds.height) * 0.02)

        // Light gray background
        context.setFillColor(CGColor(gray: 0.94, alpha: 1))
        context.fill([bounds])

        // Gray border
        context.setStrokeColor(borderColor)
        context.setLineWidth(strokeWidth)
        let inset = strokeWidth / 2
        context.stroke(bounds.insetBy(dx: inset, dy: inset))

        let minDimension = min(bounds.width, bounds.height)

        // Draw icon if there's enough space
        if minDimension >= 20 {
            locked_drawBrokenImageIcon(in: bounds, iconColor: iconColor, into: context)
        }

        // Draw filename text if there's enough space
        if let sourceLabel = memberData.sourceLabel, !sourceLabel.isEmpty,
           bounds.width >= 40, bounds.height >= 30
        {
            locked_drawSourceLabel(sourceLabel, in: bounds, color: iconColor, into: context)
        }
    }

    func locked_drawBrokenImageIcon(in bounds: CGRect, iconColor: CGColor, into context: CGContext) {
        let minDimension = min(bounds.width, bounds.height)
        let iconSize = max(minDimension * 0.4, 12)
        let iconLineWidth = max(1.0, iconSize * 0.06)

        // Center icon in upper portion of bounds (leave room for text below)
        let iconRect = CGRect(
            x: bounds.midX - iconSize / 2,
            y: bounds.midY - iconSize / 2 - iconSize * 0.15,
            width: iconSize,
            height: iconSize * 0.8
        )

        context.saveGState()
        context.setStrokeColor(iconColor)
        context.setFillColor(iconColor)
        context.setLineWidth(iconLineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        // Outer frame
        context.stroke(iconRect)

        let padding = iconSize * 0.15

        // Mountain (triangle)
        let mountainBase = iconRect.maxY - padding
        let mountainLeft = iconRect.minX + padding
        let mountainRight = iconRect.maxX - padding
        let mountainPeak = iconRect.minY + iconRect.height * 0.4

        context.beginPath()
        context.move(to: CGPoint(x: mountainLeft, y: mountainBase))
        context.addLine(to: CGPoint(x: (mountainLeft + mountainRight) / 2, y: mountainPeak))
        context.addLine(to: CGPoint(x: mountainRight, y: mountainBase))
        context.closePath()
        context.strokePath()

        // Sun (small circle in upper-right)
        let sunRadius = iconSize * 0.08
        let sunCenter = CGPoint(
            x: iconRect.maxX - padding - sunRadius,
            y: iconRect.minY + padding + sunRadius
        )
        context.fillEllipse(in: CGRect(
            x: sunCenter.x - sunRadius,
            y: sunCenter.y - sunRadius,
            width: sunRadius * 2,
            height: sunRadius * 2
        ))

        // Diagonal strike-through line across the whole icon
        context.setStrokeColor(CGColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1))
        context.setLineWidth(iconLineWidth * 1.5)
        context.beginPath()
        context.move(to: CGPoint(x: iconRect.minX, y: iconRect.minY))
        context.addLine(to: CGPoint(x: iconRect.maxX, y: iconRect.maxY))
        context.strokePath()

        context.restoreGState()
    }

    func locked_drawSourceLabel(_ label: String, in bounds: CGRect, color: CGColor, into context: CGContext) {
        let fontSize = max(min(bounds.width * 0.08, bounds.height * 0.1), 6)
        let padding = fontSize * 0.5

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NativeFont.systemFont(ofSize: fontSize),
            NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String): true,
        ]
        let attrString = NSAttributedString(string: label, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attrString)

        // Truncate if necessary
        let maxWidth = Double(bounds.width - padding * 2)
        var typographicAscent: CGFloat = 0
        var typographicDescent: CGFloat = 0
        let textWidth = CTLineGetTypographicBounds(line, &typographicAscent, &typographicDescent, nil)

        let drawnLine: CTLine
        if textWidth > maxWidth {
            let truncationAttr = NSAttributedString(string: "\u{2026}", attributes: attributes)
            let truncationToken = CTLineCreateWithAttributedString(truncationAttr)
            drawnLine = CTLineCreateTruncatedLine(line, maxWidth, .end, truncationToken) ?? line
        } else {
            drawnLine = line
        }

        // Recalculate width of the line we'll actually draw
        var drawnAscent: CGFloat = 0
        var drawnDescent: CGFloat = 0
        let drawnWidth = CTLineGetTypographicBounds(drawnLine, &drawnAscent, &drawnDescent, nil)

        // Position text centered horizontally, in the lower portion of bounds
        let textX = bounds.midX - CGFloat(drawnWidth) / 2
        let textY = bounds.midY + bounds.height * 0.25

        // CoreText draws in Y-up space; flip locally for the text
        context.saveGState()
        context.setFillColor(color)
        context.translateBy(x: textX, y: textY + drawnAscent)
        context.scaleBy(x: 1, y: -1)
        CTLineDraw(drawnLine, context)
        context.restoreGState()
    }

    func locked_image(_ memberData: inout MemberData) -> CGImage? {
        if let imageCache = memberData.imageCache {
            return imageCache
        }
        guard let imageData = memberData.imageData,
              let source = CGImageSourceCreateWithData(imageData as CFData,
                                                       [kCGImageSourceShouldCache: true] as CFDictionary) else {
            return nil
        }
        if let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            memberData.imageCache = image
            return image
        }
        return nil
    }

    func locked_willDrawRect(_ memberData: inout MemberData) -> CGRect {
        locked_globalBounds(&memberData)
    }
    
    func locked_globalBounds(_ memberData: inout MemberData) -> CGRect {
        memberData.transform.apply(to: locked_structureBounds(&memberData))
    }

    func locked_sampleColor(_ memberData: inout MemberData, at canvasLocation: CGPoint) -> Color? {
        guard let cgImage = locked_image(&memberData) else { return nil }
        guard let inverse = memberData.transform.inverted() else { return nil }

        let localPoint = inverse.applying(to: Point(canvasLocation))

        guard localPoint.x >= 0, localPoint.y >= 0,
            localPoint.x < memberData.width, localPoint.y < memberData.height
        else { return nil }

        let scaleX = Double(cgImage.width) / memberData.width
        let scaleY = Double(cgImage.height) / memberData.height
        let pixelX = Int(localPoint.x * scaleX)
        let pixelY = Int(localPoint.y * scaleY)

        guard pixelX >= 0, pixelX < cgImage.width,
            pixelY >= 0, pixelY < cgImage.height
        else { return nil }

        // Draw 1x1 pixel into a known-format context to avoid parsing arbitrary pixel formats
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        guard let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(
            cgImage,
            in: CGRect(
                x: -pixelX, y: -(cgImage.height - 1 - pixelY),
                width: cgImage.width, height: cgImage.height
            )
        )

        guard let data = context.data else { return nil }
        let pixel = data.assumingMemoryBound(to: UInt8.self)
        let r = Double(pixel[0]) / 255.0
        let g = Double(pixel[1]) / 255.0
        let b = Double(pixel[2]) / 255.0
        let a = Double(pixel[3]) / 255.0

        // Unpremultiply alpha
        if a > 0 {
            return Color(red: r / a, green: g / a, blue: b / a, alpha: a)
        } else {
            return Color(red: 0, green: 0, blue: 0, alpha: 0)
        }
    }
}
