import SwiftUI

public struct SelectableList<Content: View, SelectionValue: Hashable & Defaultable>: View {
    @State private var selection = SelectionValue.defaultValue()
    private let content: () -> Content
    private let sourceValue: SelectionValue
    private let onChange: (SelectionValue) -> Void
    
    public init(
        selection source: SelectionValue,
        onChange: @escaping (SelectionValue) -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.sourceValue = source
        self.onChange = onChange
        self.content = content
    }
    
    public var body: some View {
        List(selection: $selection, content: content)
            .onChange(of: sourceValue, initial: true) { old, new in
                selection = sourceValue
            }
            .onChange(of: selection) { old, new in
                guard old != new && new != sourceValue else {
                    return
                }
                onChange(new)
            }
    }
}
