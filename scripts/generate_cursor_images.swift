#!/usr/bin/env swift

// Generates cursor PNG images for BaseUIKit.
// Usage: swift scripts/generate_cursor_images.swift
// Output: Sources/BaseUIKit/Resources/pen_close_path.png (1x)
//         Sources/BaseUIKit/Resources/pen_close_path@2x.png (2x)
//         Sources/BaseUIKit/Resources/pen_add_point.png (1x)
//         Sources/BaseUIKit/Resources/pen_add_point@2x.png (2x)
//         Sources/BaseUIKit/Resources/pen_remove_point.png (1x)
//         Sources/BaseUIKit/Resources/pen_remove_point@2x.png (2x)
//         Sources/BaseUIKit/Resources/pen_continue.png (1x)
//         Sources/BaseUIKit/Resources/pen_continue@2x.png (2x)

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func drawPenClosePathCursor(context: CGContext, size: Int) {
    let scale = Double(size) / 21.0
    let center = Double(size) / 2.0

    context.setLineCap(.butt)
    context.setLineJoin(.miter)

    let armLength = 7.0 * scale

    // White outline for contrast
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.setLineWidth(3.0 * scale)
    context.move(to: CGPoint(x: center - armLength, y: center))
    context.addLine(to: CGPoint(x: center + armLength, y: center))
    context.move(to: CGPoint(x: center, y: center - armLength))
    context.addLine(to: CGPoint(x: center, y: center + armLength))
    context.strokePath()

    // Black crosshair
    context.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    context.setLineWidth(1.0 * scale)
    context.move(to: CGPoint(x: center - armLength, y: center))
    context.addLine(to: CGPoint(x: center + armLength, y: center))
    context.move(to: CGPoint(x: center, y: center - armLength))
    context.addLine(to: CGPoint(x: center, y: center + armLength))
    context.strokePath()

    // Small circle indicator at bottom-right
    let circleSize = 7.0 * scale
    let circleOffset = 3.0 * scale
    let circleRect = CGRect(
        x: center + circleOffset,
        y: center + circleOffset,
        width: circleSize,
        height: circleSize
    )

    // White circle outline
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.setLineWidth(3.0 * scale)
    context.strokeEllipse(in: circleRect)

    // Black circle
    context.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    context.setLineWidth(1.0 * scale)
    context.strokeEllipse(in: circleRect)
}

func drawPenAddPointCursor(context: CGContext, size: Int) {
    let scale = Double(size) / 21.0
    let center = Double(size) / 2.0

    context.setLineCap(.butt)
    context.setLineJoin(.miter)

    let armLength = 7.0 * scale

    // White outline for contrast
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.setLineWidth(3.0 * scale)
    context.move(to: CGPoint(x: center - armLength, y: center))
    context.addLine(to: CGPoint(x: center + armLength, y: center))
    context.move(to: CGPoint(x: center, y: center - armLength))
    context.addLine(to: CGPoint(x: center, y: center + armLength))
    context.strokePath()

    // Black crosshair
    context.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    context.setLineWidth(1.0 * scale)
    context.move(to: CGPoint(x: center - armLength, y: center))
    context.addLine(to: CGPoint(x: center + armLength, y: center))
    context.move(to: CGPoint(x: center, y: center - armLength))
    context.addLine(to: CGPoint(x: center, y: center + armLength))
    context.strokePath()

    // Small plus indicator at bottom-right
    let plusHalf = 3.5 * scale
    let plusOffset = 6.5 * scale
    let plusCenter = CGPoint(x: center + plusOffset, y: center + plusOffset)

    // White plus outline
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.setLineWidth(3.0 * scale)
    context.move(to: CGPoint(x: plusCenter.x - plusHalf, y: plusCenter.y))
    context.addLine(to: CGPoint(x: plusCenter.x + plusHalf, y: plusCenter.y))
    context.move(to: CGPoint(x: plusCenter.x, y: plusCenter.y - plusHalf))
    context.addLine(to: CGPoint(x: plusCenter.x, y: plusCenter.y + plusHalf))
    context.strokePath()

    // Black plus
    context.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    context.setLineWidth(1.0 * scale)
    context.move(to: CGPoint(x: plusCenter.x - plusHalf, y: plusCenter.y))
    context.addLine(to: CGPoint(x: plusCenter.x + plusHalf, y: plusCenter.y))
    context.move(to: CGPoint(x: plusCenter.x, y: plusCenter.y - plusHalf))
    context.addLine(to: CGPoint(x: plusCenter.x, y: plusCenter.y + plusHalf))
    context.strokePath()
}

func drawPenRemovePointCursor(context: CGContext, size: Int) {
    let scale = Double(size) / 21.0
    let center = Double(size) / 2.0

    context.setLineCap(.butt)
    context.setLineJoin(.miter)

    let armLength = 7.0 * scale

    // White outline for contrast
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.setLineWidth(3.0 * scale)
    context.move(to: CGPoint(x: center - armLength, y: center))
    context.addLine(to: CGPoint(x: center + armLength, y: center))
    context.move(to: CGPoint(x: center, y: center - armLength))
    context.addLine(to: CGPoint(x: center, y: center + armLength))
    context.strokePath()

    // Black crosshair
    context.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    context.setLineWidth(1.0 * scale)
    context.move(to: CGPoint(x: center - armLength, y: center))
    context.addLine(to: CGPoint(x: center + armLength, y: center))
    context.move(to: CGPoint(x: center, y: center - armLength))
    context.addLine(to: CGPoint(x: center, y: center + armLength))
    context.strokePath()

    // Small minus indicator at bottom-right
    let minusHalf = 3.5 * scale
    let minusOffset = 6.5 * scale
    let minusCenter = CGPoint(x: center + minusOffset, y: center + minusOffset)

    // White minus outline
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.setLineWidth(3.0 * scale)
    context.move(to: CGPoint(x: minusCenter.x - minusHalf, y: minusCenter.y))
    context.addLine(to: CGPoint(x: minusCenter.x + minusHalf, y: minusCenter.y))
    context.strokePath()

    // Black minus
    context.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    context.setLineWidth(1.0 * scale)
    context.move(to: CGPoint(x: minusCenter.x - minusHalf, y: minusCenter.y))
    context.addLine(to: CGPoint(x: minusCenter.x + minusHalf, y: minusCenter.y))
    context.strokePath()
}

func drawPenContinueCursor(context: CGContext, size: Int) {
    let scale = Double(size) / 21.0
    let center = Double(size) / 2.0

    context.setLineCap(.butt)
    context.setLineJoin(.miter)

    let armLength = 7.0 * scale

    // White outline for contrast
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.setLineWidth(3.0 * scale)
    context.move(to: CGPoint(x: center - armLength, y: center))
    context.addLine(to: CGPoint(x: center + armLength, y: center))
    context.move(to: CGPoint(x: center, y: center - armLength))
    context.addLine(to: CGPoint(x: center, y: center + armLength))
    context.strokePath()

    // Black crosshair
    context.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    context.setLineWidth(1.0 * scale)
    context.move(to: CGPoint(x: center - armLength, y: center))
    context.addLine(to: CGPoint(x: center + armLength, y: center))
    context.move(to: CGPoint(x: center, y: center - armLength))
    context.addLine(to: CGPoint(x: center, y: center + armLength))
    context.strokePath()

    // Small right-arrow indicator at bottom-right
    // Horizontal shaft plus a chevron head pointing right.
    let arrowOffset = 6.5 * scale
    let arrowCenter = CGPoint(x: center + arrowOffset, y: center + arrowOffset)
    let shaftHalf = 3.5 * scale
    let headSize = 2.5 * scale

    // White arrow outline
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.setLineWidth(3.0 * scale)
    context.move(to: CGPoint(x: arrowCenter.x - shaftHalf, y: arrowCenter.y))
    context.addLine(to: CGPoint(x: arrowCenter.x + shaftHalf, y: arrowCenter.y))
    context.move(to: CGPoint(x: arrowCenter.x + shaftHalf - headSize, y: arrowCenter.y - headSize))
    context.addLine(to: CGPoint(x: arrowCenter.x + shaftHalf, y: arrowCenter.y))
    context.addLine(to: CGPoint(x: arrowCenter.x + shaftHalf - headSize, y: arrowCenter.y + headSize))
    context.strokePath()

    // Black arrow
    context.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    context.setLineWidth(1.0 * scale)
    context.move(to: CGPoint(x: arrowCenter.x - shaftHalf, y: arrowCenter.y))
    context.addLine(to: CGPoint(x: arrowCenter.x + shaftHalf, y: arrowCenter.y))
    context.move(to: CGPoint(x: arrowCenter.x + shaftHalf - headSize, y: arrowCenter.y - headSize))
    context.addLine(to: CGPoint(x: arrowCenter.x + shaftHalf, y: arrowCenter.y))
    context.addLine(to: CGPoint(x: arrowCenter.x + shaftHalf - headSize, y: arrowCenter.y + headSize))
    context.strokePath()
}

func generatePNG(size: Int, draw: (CGContext, Int) -> Void, path: String) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fatalError("Failed to create CGContext")
    }

    // Flip to match AppKit coordinate system (origin at bottom-left)
    // Our drawing uses top-left origin, so flip
    context.translateBy(x: 0, y: Double(size))
    context.scaleBy(x: 1, y: -1)

    draw(context, size)

    guard let image = context.makeImage() else {
        fatalError("Failed to create CGImage")
    }

    let url = URL(fileURLWithPath: path)
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        fatalError("Failed to create image destination at \(path)")
    }

    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        fatalError("Failed to write PNG to \(path)")
    }

    print("Generated: \(path) (\(size)x\(size))")
}

// Resolve output directory relative to script location
let scriptDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let resourceDir = scriptDir
    .deletingLastPathComponent()
    .appendingPathComponent("Sources/BaseUIKit/Resources")

try FileManager.default.createDirectory(at: resourceDir, withIntermediateDirectories: true)

generatePNG(size: 21, draw: drawPenClosePathCursor, path: resourceDir.appendingPathComponent("pen_close_path.png").path)
generatePNG(size: 42, draw: drawPenClosePathCursor, path: resourceDir.appendingPathComponent("pen_close_path@2x.png").path)
generatePNG(size: 21, draw: drawPenAddPointCursor, path: resourceDir.appendingPathComponent("pen_add_point.png").path)
generatePNG(size: 42, draw: drawPenAddPointCursor, path: resourceDir.appendingPathComponent("pen_add_point@2x.png").path)
generatePNG(size: 21, draw: drawPenRemovePointCursor, path: resourceDir.appendingPathComponent("pen_remove_point.png").path)
generatePNG(size: 42, draw: drawPenRemovePointCursor, path: resourceDir.appendingPathComponent("pen_remove_point@2x.png").path)
generatePNG(size: 21, draw: drawPenContinueCursor, path: resourceDir.appendingPathComponent("pen_continue.png").path)
generatePNG(size: 42, draw: drawPenContinueCursor, path: resourceDir.appendingPathComponent("pen_continue@2x.png").path)
