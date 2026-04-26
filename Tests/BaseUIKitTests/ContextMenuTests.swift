import Testing

@testable import BaseUIKit

@MainActor
struct ContextMenuTests {
    // MARK: - Result builder

    @Test func builderProducesItemElement() {
        let menu = ContextMenu {
            ContextMenuItem("Foo") {}
        }

        #expect(menu.elements.count == 1)
        guard case let .item(item) = menu.elements[0] else {
            #expect(Bool(false), "expected item")
            return
        }
        #expect(item.title == "Foo")
    }

    @Test func builderProducesDividerElement() {
        let menu = ContextMenu {
            ContextMenuItem("A") {}
            ContextMenuDivider()
            ContextMenuItem("B") {}
        }

        #expect(menu.elements.count == 3)
        if case .divider = menu.elements[1] { /* ok */ } else {
            #expect(Bool(false), "expected divider in middle position")
        }
    }

    @Test func builderProducesNestedSubmenu() {
        let menu = ContextMenu {
            ContextSubmenu("More") {
                ContextMenuItem("Inner") {}
            }
        }

        guard case let .submenu(title, elements) = menu.elements[0] else {
            #expect(Bool(false), "expected submenu")
            return
        }
        #expect(title == "More")
        #expect(elements.count == 1)
        guard case let .item(inner) = elements[0] else {
            #expect(Bool(false), "expected inner item")
            return
        }
        #expect(inner.title == "Inner")
    }

    @Test func builderSupportsConditional() {
        func makeMenu(includeOptional: Bool) -> ContextMenu {
            ContextMenu {
                ContextMenuItem("Always") {}
                if includeOptional {
                    ContextMenuItem("Optional") {}
                }
            }
        }

        #expect(makeMenu(includeOptional: false).elements.count == 1)
        #expect(makeMenu(includeOptional: true).elements.count == 2)
    }

    @Test func builderSupportsForLoop() {
        let titles = ["A", "B", "C"]
        let menu = ContextMenu {
            for title in titles {
                ContextMenuItem(title) {}
            }
        }

        #expect(menu.elements.count == 3)
    }

    @Test func actionInvokesWhenCalled() {
        var called = 0
        let menu = ContextMenu {
            ContextMenuItem("Tap") { called += 1 }
        }

        guard case let .item(item) = menu.elements[0] else {
            #expect(Bool(false), "expected item")
            return
        }
        item.action()
        item.action()

        #expect(called == 2)
    }

    @Test func arrayInitProducesElements() {
        let menu = ContextMenu(elements: [
            .item(ContextMenuItem("A") {}),
            .divider,
            .item(ContextMenuItem("B") {}),
        ])

        #expect(menu.elements.count == 3)
    }

    // MARK: - UIKit divider grouping

    #if canImport(UIKit)
    @Test func uikitGroupsItemsBetweenDividersIntoInlineSections() {
        let menu = ContextMenu {
            ContextMenuItem("A") {}
            ContextMenuItem("B") {}
            ContextMenuDivider()
            ContextMenuItem("C") {}
        }

        let sections = groupedSections(menu.elements)

        // Two sections: {A, B} and {C}.
        #expect(sections.count == 2)
    }

    @Test func uikitGroupsLeadingTrailingDividersCorrectly() {
        let menu = ContextMenu {
            ContextMenuDivider()
            ContextMenuItem("A") {}
            ContextMenuDivider()
        }

        let sections = groupedSections(menu.elements)

        // Leading divider creates no empty group; trailing divider also no
        // trailing empty group. One section: {A}.
        #expect(sections.count == 1)
    }
    #endif
}
