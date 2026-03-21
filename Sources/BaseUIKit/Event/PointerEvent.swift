import Foundation
import BaseKit

public struct PointerEvent: Hashable, Sendable {
    public enum Button: Hashable, Sendable {
        case left, right, other
    }
    public enum State: Hashable, Sendable {
        case down
        case up
        case move
        case drag
        case cancel
        case multitouchChange
    }
    public let state: State
    public let location: Point
    public let locationInWindowCoords: Point
    public let keyboardModifiers: KeyboardModifiers
    public let when: Date
    public let button: Button
    public let clickCount: Int
    public let touches: Set<Touch>
    public let canvas: EventCanvas
    public let responderState: ResponderState
    
    public init(
        state: State,
        location: Point,
        locationInWindowCoords: Point,
        keyboardModifiers: KeyboardModifiers,
        when: Date,
        button: Button,
        clickCount: Int = 1,
        touches: Set<Touch>,
        canvas: EventCanvas,
        responderState: ResponderState
    ) {
        self.state = state
        self.location = location
        self.locationInWindowCoords = locationInWindowCoords
        self.keyboardModifiers = keyboardModifiers
        self.when = when
        self.button = button
        self.clickCount = clickCount
        self.touches = touches
        self.canvas = canvas
        self.responderState = responderState
    }
}
