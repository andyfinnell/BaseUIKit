import SwiftUI

public protocol HasDisabled {
    var isDisabled: Bool { get }
}

public struct CommandCallback<each Parameter>: Hashable, Sendable, Identifiable, HasDisabled {
    public let id: String
    public let isEnabled: Bool
    private let action: @MainActor (repeat each Parameter) -> Void

    public init(
        _ name: String,
        isEnabled: Bool = true,
        action: @escaping @MainActor (repeat each Parameter) -> Void
    ) {
        self.id = name
        self.isEnabled = isEnabled
        self.action = action
    }

    public var isDisabled: Bool { !isEnabled }

    @MainActor
    public func callAsFunction(_ parameters: repeat each Parameter) {
        action(repeat each parameters)
    }

    public static func ==(lhs: CommandCallback, rhs: CommandCallback) -> Bool {
        lhs.id == rhs.id && lhs.isEnabled == rhs.isEnabled
    }

    public func hash(into hasher: inout Hasher) {
        id.hash(into: &hasher)
        isEnabled.hash(into: &hasher)
    }
}

public extension View {
    /// Defines a command callback that is published as a focused scene value.
    ///
    /// - Parameters:
    ///   - keyPath: The `FocusedValues` key path to publish on.
    ///   - scopeID: A stable identifier that distinguishes this view's commands
    ///     from the same command defined in other scenes (e.g., other document windows).
    ///     Use a value that is constant across re-renders of this view but unique
    ///     per scene, such as a `@State` UUID.
    ///   - isEnabled: Whether the command is currently enabled.
    ///   - action: The action to perform when the command is invoked.
    func defineCommand<each Parameter>(
        _ keyPath: WritableKeyPath<FocusedValues, CommandCallback<repeat each Parameter>?>,
        scopeID: some Hashable & Sendable,
        isEnabled: Bool = true,
        action: @escaping @MainActor (repeat each Parameter) -> Void
    ) -> some View {
        focusedSceneValue(keyPath, CommandCallback(
            "\(scopeID)",
            isEnabled: isEnabled,
            action: action
        ))
    }
}

public extension Optional where Wrapped: HasDisabled {
    var isDisabled: Bool {
        map { $0.isDisabled } ?? true
    }
}
