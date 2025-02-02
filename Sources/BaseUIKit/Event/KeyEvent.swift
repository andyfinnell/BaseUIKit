import Foundation

public struct KeyEvent: Hashable, Sendable {
    public enum State: Hashable, Sendable {
        case down
        case up
        case modifiers
    }
    public let state: State
    public let keyboardModifiers: KeyboardModifiers
    public let when: Date
    public let characters: String
    public let charactersIgnoringModifiers: String
    public let isRepeat: Bool
    public let rawKeyCode: UInt16
    public let keyCode: KeyCode?
    
    public init(
        state: State,
        keyboardModifiers: KeyboardModifiers,
        when: Date,
        characters: String,
        charactersIgnoringModifiers: String,
        isRepeat: Bool,
        rawKeyCode: UInt16
    ) {
        self.state = state
        self.keyboardModifiers = keyboardModifiers
        self.when = when
        self.characters = characters
        self.charactersIgnoringModifiers = charactersIgnoringModifiers
        self.isRepeat = isRepeat
        self.rawKeyCode = rawKeyCode
        self.keyCode = KeyCode(rawValue: rawKeyCode)
    }
}
