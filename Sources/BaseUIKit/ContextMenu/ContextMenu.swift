/// A platform-neutral context menu definition. Bridges to `NSMenu` on macOS
/// (via `ContextMenu+AppKit.swift`) and `UIMenu`/`UIContextMenuConfiguration`
/// on iOS (via `ContextMenu+UIKit.swift`).
///
/// Note on naming: SwiftUI also defines a `ContextMenu` type. They don't
/// usually collide because SwiftUI's is referenced through the
/// `.contextMenu { ... }` modifier, not by its type name. If a call site
/// imports both modules and references the type by name, disambiguate with
/// `BaseUIKit.ContextMenu` or a file-local `typealias`.
@MainActor
public struct ContextMenu: Sendable {
    public let elements: [Element]

    public init(@ContextMenuBuilder _ build: () -> [Element]) {
        self.elements = build()
    }

    public init(elements: [Element]) {
        self.elements = elements
    }

    public enum Element: Sendable {
        case item(ContextMenuItem)
        case divider
        case submenu(title: String, elements: [Element])
    }
}

/// A single actionable item in a context menu.
@MainActor
public struct ContextMenuItem: Sendable {
    public enum Role: Sendable {
        case `default`
        /// Hint that the item is destructive (e.g. delete). Rendered with
        /// system destructive styling on platforms that support it (UIKit).
        /// Ignored on macOS — the system convention is plain text.
        case destructive
    }

    public let title: String
    public let role: Role
    public let isEnabled: Bool
    public let action: @MainActor () -> Void

    public init(
        _ title: String,
        role: Role = .default,
        isEnabled: Bool = true,
        action: @MainActor @escaping () -> Void
    ) {
        self.title = title
        self.role = role
        self.isEnabled = isEnabled
        self.action = action
    }
}

/// Marker placed between groups of items to render a separator.
public struct ContextMenuDivider: Sendable {
    public init() {}
}

/// A nested submenu. Use within a `ContextMenuBuilder` body.
@MainActor
public struct ContextSubmenu: Sendable {
    public let title: String
    public let elements: [ContextMenu.Element]

    public init(_ title: String, @ContextMenuBuilder _ build: () -> [ContextMenu.Element]) {
        self.title = title
        self.elements = build()
    }
}

/// Result builder for declaring `ContextMenu` contents. Supports items,
/// dividers, submenus, conditionals, and `for` loops.
@MainActor
@resultBuilder
public enum ContextMenuBuilder {
    public static func buildBlock(_ parts: [ContextMenu.Element]...) -> [ContextMenu.Element] {
        parts.flatMap { $0 }
    }

    public static func buildExpression(_ item: ContextMenuItem) -> [ContextMenu.Element] {
        [.item(item)]
    }

    public static func buildExpression(_ divider: ContextMenuDivider) -> [ContextMenu.Element] {
        [.divider]
    }

    public static func buildExpression(_ submenu: ContextSubmenu) -> [ContextMenu.Element] {
        [.submenu(title: submenu.title, elements: submenu.elements)]
    }

    public static func buildOptional(_ parts: [ContextMenu.Element]?) -> [ContextMenu.Element] {
        parts ?? []
    }

    public static func buildEither(first parts: [ContextMenu.Element]) -> [ContextMenu.Element] {
        parts
    }

    public static func buildEither(second parts: [ContextMenu.Element]) -> [ContextMenu.Element] {
        parts
    }

    public static func buildArray(_ parts: [[ContextMenu.Element]]) -> [ContextMenu.Element] {
        parts.flatMap { $0 }
    }
}
