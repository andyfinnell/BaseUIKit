import SwiftUI

public struct Switch<Label: View>: View {
    @State private var isOn = [false]
    private let sourceValue: [Bool]
    private let onChange: (Bool) -> Void
    private let label: () -> Label
    
    public init(
        isOn: Bool,
        onChange: @escaping (Bool) -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        sourceValue = [isOn]
        self.onChange = onChange
        self.label = label
    }
    
    public init(
        _ titleKey: LocalizedStringKey,
        isOn: Bool,
        onChange: @escaping (Bool) -> Void
    ) where Label == Text {
        sourceValue = [isOn]
        self.onChange = onChange
        self.label = { Text(titleKey) }
    }

    public init<C: RandomAccessCollection>(
        sources: C,
        isOn: KeyPath<C.Element, Bool>,
        onChange: @escaping (Bool) -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        sourceValue = sources.map { $0[keyPath: isOn] }
        self.onChange = onChange
        self.label = label
    }

    public init<C: RandomAccessCollection>(
        _ titleKey: LocalizedStringKey,
        sources: C,
        isOn: KeyPath<C.Element, Bool>,
        onChange: @escaping (Bool) -> Void
    ) where Label == Text {
        sourceValue = sources.map { $0[keyPath: isOn] }
        self.onChange = onChange
        self.label = { Text(titleKey) }
    }

    public var body: some View {
        Toggle(sources: $isOn, isOn: \.self, label: label)
            .onChange(of: sourceValue, initial: true) { old, new in
                isOn = sourceValue
            }
            .onChange(of: isOn) { old, new in
                guard old != new && new != sourceValue, let newValue = new.first else {
                    return
                }
                onChange(newValue)
            }
    }
}
