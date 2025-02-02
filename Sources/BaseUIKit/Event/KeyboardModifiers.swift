
public struct KeyboardModifiers: OptionSet, Hashable, Sendable {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let shift = KeyboardModifiers(rawValue: 1 << 0)
    public static let option = KeyboardModifiers(rawValue: 1 << 1)
    public static let control = KeyboardModifiers(rawValue: 1 << 2)
    public static let command = KeyboardModifiers(rawValue: 1 << 3)
    public static let capsLock = KeyboardModifiers(rawValue: 1 << 4)
    public static let function = KeyboardModifiers(rawValue: 1 << 5)
}
