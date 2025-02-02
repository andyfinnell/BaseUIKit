import BaseKit
import Foundation

public struct TouchID: Hashable, Sendable {
    private let id: ObjectIdentifier
    
    public init<T: AnyObject>(_ instance: T) {
        id = ObjectIdentifier(instance)
    }
}

public struct Touch: Hashable, Sendable, Identifiable {
    public enum Phase: Hashable, Sendable {
        case began
        case moved
        case stationary
        case ended
        case cancelled
        case regionEntered
        case regionMoved
        case regionExited
        case unknown
    }
    public let id: TouchID
    public let phase: Phase
    public let location: Point
    public let when: Date
    public let tapCount: Int
    
    public init(id: TouchID, phase: Phase, location: Point, when: Date, tapCount: Int) {
        self.id = id
        self.phase = phase
        self.location = location
        self.when = when
        self.tapCount = tapCount
    }
}
