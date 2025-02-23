import SwiftUI

public protocol Defaultable {
    static func defaultValue() -> Self
}

extension Optional: Defaultable {
    public static func defaultValue() -> Optional<Wrapped> {
        Optional.none
    }
}

public struct Chooser<Content: View, Label: View, Value: Hashable & Defaultable>: View {
    // This has to have at least one value in it or Picker crashes
    @State private var selection = [Value.defaultValue()]
    private let source: [Value]
    private let onChange: (Value) -> Void
    private let content: () -> Content
    private let label: () -> Label
    
    public init(
        selection source: Value,
        onChange: @escaping (Value) -> Void,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.source = [source]
        self.onChange = onChange
        self.content = content
        self.label = label
    }

    public init(
        _ titleKey: LocalizedStringKey,
        selection source: Value,
        onChange: @escaping (Value) -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) where Label == Text {
        self.source = [source]
        self.onChange = onChange
        self.content = content
        self.label = { Text(titleKey) }
    }

    public init<C: RandomAccessCollection>(
        sources: C,
        selection source: KeyPath<C.Element, Value>,
        onChange: @escaping (Value) -> Void,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.source = sources.map { $0[keyPath: source] }
        self.onChange = onChange
        self.content = content
        self.label = label
    }

    public init<C: RandomAccessCollection>(
        _ titleKey: LocalizedStringKey,
        sources: C,
        selection source: KeyPath<C.Element, Value>,
        onChange: @escaping (Value) -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) where Label == Text {
        self.source = sources.map { $0[keyPath: source] }
        self.onChange = onChange
        self.content = content
        self.label = { Text(titleKey) }
    }

    public var body: some View {
        Picker(sources: $selection, selection: \.self, content: content, label: label)
            .onChange(of: source, initial: true) { old, new in
                selection = source
            }
            .onChange(of: selection) { old, new in
                guard old != new && new != source, let newValue = new.first else {
                    return
                }
                onChange(newValue)
            }
    }
}
