#if canImport(AppKit)
import AppKit

public struct ResponderState: Sendable, Hashable {
    public let window: NSWindow?
    public let responder: NSResponder?
    
    public init(window: NSWindow?, responder: NSResponder?) {
        self.window = window
        self.responder = responder
    }
}

#endif

#if canImport(UIKit)
import UIKit

public struct ResponderState: Sendable, Hashable {
    public let responder: UIResponder?
    
    public init(responder: UIResponder?) {
        self.responder = responder
    }
}
#endif
