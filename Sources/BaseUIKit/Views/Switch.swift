import SwiftUI

public struct Switch<Label: View>: View {
    @State private var isOn = [false]
    private let binding: SmartCollectionBind<[Bool]>
    private let label: ViewHolder<Label>
    
    public init(
        isOn: Bool,
        onChange: @escaping (Bool) -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        binding = SmartCollectionBind([isOn], onChange)
        self.label = ViewHolder(label)
    }
    
    public init(
        _ titleKey: LocalizedStringKey,
        isOn: Bool,
        onChange: @escaping (Bool) -> Void
    ) where Label == Text {
        binding = SmartCollectionBind([isOn], onChange)
        self.label = ViewHolder({ Text(titleKey) })
    }

    public init<C: RandomAccessCollection>(
        sources: C,
        isOn: KeyPath<C.Element, Bool>,
        onChange: @escaping (Bool) -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        binding = SmartCollectionBind(sources.map { $0[keyPath: isOn] }, onChange)
        self.label = ViewHolder(label)
    }

    public init<C: RandomAccessCollection>(
        _ titleKey: LocalizedStringKey,
        sources: C,
        isOn: KeyPath<C.Element, Bool>,
        onChange: @escaping (Bool) -> Void
    ) where Label == Text {
        binding = SmartCollectionBind(sources.map { $0[keyPath: isOn] }, onChange)
        self.label = ViewHolder({ Text(titleKey) })
    }

    public var body: some View {        
        Toggle(sources: $isOn, isOn: \.self, label: label.content)
            .sync(binding, $isOn)
    }
}
