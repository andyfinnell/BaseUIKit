 
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
        }
    }
    #endif
}
