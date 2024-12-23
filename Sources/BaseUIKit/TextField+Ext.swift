import SwiftUI

public extension TextField {
    init<C: RandomAccessCollection & Sendable>(
        sources: C,
        text: KeyPath<C.Element, Binding<String>> & Sendable,
        prompt: Text? = nil,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.init(
            text: Binding<String>(sources: sources, text: text),
            prompt: prompt,
            label: label
        )
    }
}
