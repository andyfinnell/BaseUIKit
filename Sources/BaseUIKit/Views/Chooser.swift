import SwiftUI

public protocol Defaultable {
    static func defaultValue() -> Self
}

extension Optional: Defaultable {
    public static func defaultValue() -> Optional<Wrapped> {
        Optional.none
    }
}

public struct Chooser<Content: View, Label: View, Value: Hashable & Defaultable & Sendable>: View {
    // This has to have at least one value in it or Picker crashes
    @State private var selection = [Value.defaultValue()]
    private let source: SmartCollectionBind<[Value]>
    private let content: ViewHolder<Content>
    private let label: ViewHolder<Label>
    
    public init(
        selection source: Value,
        onChange: @escaping (Value) -> Void,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.source = SmartCollectionBind([source], onChange)
        self.content = ViewHolder(content)
        self.label = ViewHolder(label)
    }

    public init(
        selection: Binding<Value>,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.init(selection: selection.wrappedValue, onChange: { selection.wrappedValue = $0 }, content: content, label: label)
    }

    public init(
        _ titleKey: LocalizedStringKey,
        selection source: Value,
        onChange: @escaping (Value) -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) where Label == Text {
        self.source = SmartCollectionBind([source], onChange)
        self.content = ViewHolder(content)
        self.label = ViewHolder({ Text(titleKey) })
    }

    public init(
        _ titleKey: LocalizedStringKey,
        selection: Binding<Value>,
        @ViewBuilder content: @escaping () -> Content
    ) where Label == Text {
        self.init(titleKey, selection: selection.wrappedValue, onChange: { selection.wrappedValue = $0 }, content: content)
    }

    public init<C: RandomAccessCollection>(
        sources: C,
        selection source: KeyPath<C.Element, Value>,
        onChange: @escaping (Value) -> Void,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.source = SmartCollectionBind(sources.map { $0[keyPath: source] }, onChange)
        self.content = ViewHolder(content)
        self.label = ViewHolder(label)
    }

    public init<C: RandomAccessCollection>(
        _ titleKey: LocalizedStringKey,
        sources: C,
        selection source: KeyPath<C.Element, Value>,
        onChange: @escaping (Value) -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) where Label == Text {
        self.source = SmartCollectionBind(sources.map { $0[keyPath: source] }, onChange)
        self.content = ViewHolder(content)
        self.label = ViewHolder({ Text(titleKey) })
    }

    public var body: some View {
        Picker(sources: $selection, selection: \.self, content: content.content, label: label.content)
            .sync(source, $selection)
    }
}
