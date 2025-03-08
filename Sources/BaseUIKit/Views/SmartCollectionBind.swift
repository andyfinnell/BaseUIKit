import SwiftUI

/// This is an implementation type. AppStateKit doesn't like working in SwiftUI.Bindings
/// which wants to directly manipulate @State data, but to instead use closures to send
/// Actions back through the Engine. However, closures are unstable in Equatable, despite
/// the fact in practice, for a given View, they don't change.
///
/// Therefore this type wraps the current value and closure and only compares against
/// the current value
@MainActor
struct SmartCollectionBind<Value: Equatable & RandomAccessCollection & Sendable>: Equatable {
    let value: Value
    let onChange: (Value.Element) -> Void
    
    init(_ value: Value, _ onChange: @escaping (Value.Element) -> Void) {
        self.value = value
        self.onChange = onChange
    }
    
    nonisolated static func ==(lhs: SmartCollectionBind<Value>, rhs: SmartCollectionBind<Value>) -> Bool {
        lhs.value == rhs.value
    }
}

extension View {
    /// Keep a `SmartCollectionBind` and `Bindable` in sync with each other
    func sync<Value: Equatable & RandomAccessCollection & Sendable>(_ bind: SmartCollectionBind<Value>, _ binding: Binding<Value>) -> some View {
        modifier(SmartCollectionBindModifier(bind: bind, binding: binding))
    }
}

struct SmartCollectionBindModifier<Value: Equatable & RandomAccessCollection & Sendable>: ViewModifier, Equatable {
    private let bind: SmartCollectionBind<Value>
    private let binding: Binding<Value>
    
    init(bind: SmartCollectionBind<Value>, binding: Binding<Value>) {
        self.bind = bind
        self.binding = binding
    }
    
    func body(content: Content) -> some View {
        content
            .onChange(of: bind.value, initial: true) { old, new in
                if binding.wrappedValue != bind.value {
                    binding.wrappedValue = bind.value
                }
            }
            .onChange(of: binding.wrappedValue) { old, new in
                guard old != new && new != bind.value, let newValue = new.first else {
                    return
                }
                bind.onChange(newValue)
            }

    }
    
    nonisolated static func ==(lhs: SmartCollectionBindModifier<Value>, rhs: SmartCollectionBindModifier<Value>) -> Bool {
        lhs.bind == rhs.bind
    }
}
