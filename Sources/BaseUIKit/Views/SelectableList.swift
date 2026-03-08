import SwiftUI

public struct SelectableList<Content: View, SelectionValue: Hashable & Sendable>: View {
    @State private var selection: SelectionValue? = nil
    private let content: ViewHolder<Content>
    private let sourceValue: SmartBind<SelectionValue?, ExtraEmpty>
    
    public init(
        selection source: SelectionValue?,
        onChange: @escaping (SelectionValue?) -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.sourceValue = SmartBind(source, onChange)
        self.content = ViewHolder(content)
    }

    public init(
        selection: Binding<SelectionValue?>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(selection: selection.wrappedValue, onChange: { selection.wrappedValue = $0 }, content: content)
    }
    
    public var body: some View {
        List(selection: $selection, content: content.content)
            .sync(sourceValue, $selection)
    }
}
