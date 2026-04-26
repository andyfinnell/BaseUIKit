#if canImport(UIKit)
import UIKit

public extension UIMenu {
    /// Build a `UIMenu` from a platform-neutral `ContextMenu`. Dividers are
    /// rendered by grouping the items between them into separate
    /// `UIMenu(options: .displayInline)` sections — the standard UIKit idiom
    /// for separator lines.
    @MainActor
    convenience init(contextMenu: ContextMenu) {
        self.init(title: "", children: groupedSections(contextMenu.elements))
    }
}

@MainActor
func groupedSections(_ elements: [ContextMenu.Element]) -> [UIMenuElement] {
    var sections: [UIMenuElement] = []
    var current: [ContextMenu.Element] = []

    func flush() {
        guard !current.isEmpty else { return }
        let children = current.compactMap { makeUIMenuElement(from: $0) }
        let inline = UIMenu(title: "", options: .displayInline, children: children)
        sections.append(inline)
        current = []
    }

    for element in elements {
        if case .divider = element {
            flush()
        } else {
            current.append(element)
        }
    }
    flush()
    return sections
}

@MainActor
private func makeUIMenuElement(from element: ContextMenu.Element) -> UIMenuElement? {
    switch element {
    case let .item(item):
        var attributes: UIMenuElement.Attributes = []
        if !item.isEnabled { attributes.insert(.disabled) }
        if item.role == .destructive { attributes.insert(.destructive) }
        return UIAction(title: item.title, attributes: attributes) { _ in
            item.action()
        }
    case .divider:
        // Dividers are pre-grouped by `groupedSections`. Reaching this branch
        // means a nested submenu contained a divider — split that submenu's
        // children into displayInline sections too.
        return nil
    case let .submenu(title, elements):
        return UIMenu(title: title, children: groupedSections(elements))
    }
}
#endif
