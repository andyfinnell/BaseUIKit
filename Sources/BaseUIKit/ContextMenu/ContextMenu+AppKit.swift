#if canImport(AppKit)
import AppKit

public extension NSMenu {
    /// Build an `NSMenu` from a platform-neutral `ContextMenu`.
    @MainActor
    convenience init(contextMenu: ContextMenu) {
        self.init(title: "")
        autoenablesItems = false
        for element in contextMenu.elements {
            addItem(NSMenuItem.makeFromContextMenu(element: element))
        }
    }
}

extension NSMenuItem {
    @MainActor
    static func makeFromContextMenu(element: ContextMenu.Element) -> NSMenuItem {
        switch element {
        case let .item(item):
            return makeFromContextMenuItem(item)
        case .divider:
            return NSMenuItem.separator()
        case let .submenu(title, elements):
            let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let submenu = NSMenu(title: title)
            submenu.autoenablesItems = false
            for child in elements {
                submenu.addItem(makeFromContextMenu(element: child))
            }
            menuItem.submenu = submenu
            return menuItem
        }
    }

    @MainActor
    static func makeFromContextMenuItem(_ item: ContextMenuItem) -> NSMenuItem {
        let target = ContextMenuActionTarget(action: item.action)
        let menuItem = NSMenuItem(
            title: item.title,
            action: #selector(ContextMenuActionTarget.invoke),
            keyEquivalent: ""
        )
        menuItem.target = target
        menuItem.isEnabled = item.isEnabled
        // Retain the target via the menuItem so it lives for the menu's
        // lifetime — `NSMenuItem.target` is `weak`.
        menuItem.representedObject = target
        return menuItem
    }
}

/// Trampoline that exposes a closure as an Objective-C selector for
/// `NSMenuItem.target`/`action`.
@MainActor
final class ContextMenuActionTarget: NSObject {
    private let action: @MainActor () -> Void

    init(action: @escaping @MainActor () -> Void) {
        self.action = action
    }

    @objc func invoke() {
        action()
    }
}
#endif
