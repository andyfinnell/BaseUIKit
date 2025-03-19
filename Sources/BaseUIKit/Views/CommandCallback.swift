import SwiftUI

public struct CommandCallback<each Parameter>: Hashable, Sendable, Identifiable {
    public let id: String
    private let action: @MainActor (repeat each Parameter) -> Void
    
    public init(_ name: String, action: @escaping @MainActor (repeat each Parameter) -> Void) {
        self.id = name
        self.action = action
    }
        
    @MainActor
    public func callAsFunction(_ parameters: repeat each Parameter) {
        action(repeat each parameters)
    }

    public static func ==(lhs: CommandCallback, rhs: CommandCallback) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        id.hash(into: &hasher)
    }
}

public extension View {
    func defineCommand<each Parameter>(
        _ keyPath: WritableKeyPath<FocusedValues, CommandCallback<repeat each Parameter>?>,
        file: StaticString = #file,
        line: UInt = #line,
        action: @escaping @MainActor (repeat each Parameter) -> Void
    ) -> some View {
        focusedSceneValue(keyPath, CommandCallback("command@\(file):\(line)", action: action))
    }
}
