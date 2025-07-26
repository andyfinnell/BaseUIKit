import BaseKit
import Foundation

public struct CursorEvent: Sendable, Hashable {
    public let location: Point
    public let when: Date
    public let isInside: Bool
    public let canvas: EventCanvas
    
    public init(location: Point, when: Date, isInside: Bool, canvas: EventCanvas) {
        self.location = location
        self.when = when
        self.isInside = isInside
        self.canvas = canvas
    }
}
