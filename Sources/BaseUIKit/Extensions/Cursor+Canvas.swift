 
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
        }
    }
    #endif
}
