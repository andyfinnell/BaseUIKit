 
#if canImport(AppKit)
import AppKit
#endif

public extension Cursor {
    func set() {
        #if canImport(AppKit)
        nativeCursor.set()
        #endif
    }
    
}

private extension Cursor {
    #if canImport(AppKit)
    var nativeCursor: NSCursor {
        switch self {
        case .crosshair: NSCursor.crosshair
        case .default: NSCursor.arrow
        case .zoomIn: NSCursor.zoomIn
        case .zoomOut: NSCursor.zoomOut
        case .openHand: NSCursor.openHand
        case .closedHand: NSCursor.closedHand
        case .move: NSCursor.openHand
        case .resizeNorth: NSCursor.frameResize(position: .top, directions: .all)
        case .resizeSouth: NSCursor.frameResize(position: .bottom, directions: .all)
        case .resizeEast: NSCursor.frameResize(position: .right, directions: .all)
        case .resizeWest: NSCursor.frameResize(position: .left, directions: .all)
        case .resizeNorthWest: NSCursor.frameResize(position: .topLeft, directions: .all)
        case .resizeNorthEast: NSCursor.frameResize(position: .topRight, directions: .all)
        case .resizeSouthWest: NSCursor.frameResize(position: .bottomLeft, directions: .all)
        case .resizeSouthEast: NSCursor.frameResize(position: .bottomRight, directions: .all)
        case .iBeam: NSCursor.iBeam
        case .penClosePath: Self.makePenClosePathCursor()
        case .penAddPoint: Self.makePenAddPointCursor()
        case .penRemovePoint: Self.makePenRemovePointCursor()
        case .penContinue: Self.makePenContinueCursor()
        case .penConvertPoint: Self.makePenConvertPointCursor()
        case .notAllowed: NSCursor.operationNotAllowed
        }
    }

    static func makePenClosePathCursor() -> NSCursor {
        guard let url = Bundle.module.url(
            forResource: "pen_close_path@2x",
            withExtension: "png"
        ) else {
            return NSCursor.crosshair
        }
        let image = NSImage(contentsOf: url) ?? NSImage()
        image.size = NSSize(width: 21, height: 21)
        return NSCursor(image: image, hotSpot: NSPoint(x: 10.5, y: 10.5))
    }

    static func makePenAddPointCursor() -> NSCursor {
        guard let url = Bundle.module.url(
            forResource: "pen_add_point@2x",
            withExtension: "png",
        ) else {
            return NSCursor.crosshair
        }
        let image = NSImage(contentsOf: url) ?? NSImage()
        image.size = NSSize(width: 21, height: 21)
        return NSCursor(image: image, hotSpot: NSPoint(x: 10.5, y: 10.5))
    }

    static func makePenRemovePointCursor() -> NSCursor {
        guard let url = Bundle.module.url(
            forResource: "pen_remove_point@2x",
            withExtension: "png"
        ) else {
            return NSCursor.crosshair
        }
        let image = NSImage(contentsOf: url) ?? NSImage()
        image.size = NSSize(width: 21, height: 21)
        return NSCursor(image: image, hotSpot: NSPoint(x: 10.5, y: 10.5))
    }

    static func makePenContinueCursor() -> NSCursor {
        guard let url = Bundle.module.url(
            forResource: "pen_continue@2x",
            withExtension: "png"
        ) else {
            return NSCursor.crosshair
        }
        let image = NSImage(contentsOf: url) ?? NSImage()
        image.size = NSSize(width: 21, height: 21)
        return NSCursor(image: image, hotSpot: NSPoint(x: 10.5, y: 10.5))
    }

    static func makePenConvertPointCursor() -> NSCursor {
        guard let url = Bundle.module.url(
            forResource: "pen_convert_point@2x",
            withExtension: "png"
        ) else {
            return NSCursor.crosshair
        }
        let image = NSImage(contentsOf: url) ?? NSImage()
        image.size = NSSize(width: 21, height: 21)
        return NSCursor(image: image, hotSpot: NSPoint(x: 10.5, y: 10.5))
    }
    #endif
}
