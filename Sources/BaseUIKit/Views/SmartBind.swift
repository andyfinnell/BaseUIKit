import SwiftUI

/// This is an implementation type. AppStateKit doesn't like working in SwiftUI.Bindings
/// which wants to directly manipulate @State data, but to instead use closures to send
/// Actions back through the Engine. However, closures are unstable in Equatable, despite
/// the fact in practice, for a given View, they don't change.
///
/// Therefore this type wraps the current value and closure and only compares against
/// the current value
@MainActor
struct SmartBind<Value: Equatable & Sendable>: Equatable, DynamicProperty {
    @State private var debouncer = Debouncer<Value>()

    let value: Value
    let onChange: (Value) -> Void
    
    init(_ value: Value, _ onChange: @escaping (Value) -> Void) {
        self.value = value
        self.onChange = onChange
    }
    
    func map(onChange: @escaping (Value, (Value) -> Void, Value) -> Void) -> SmartBind<Value> {
        let oldOnChange = self.onChange
        let composedOnChange: (Value) -> Void = { newValue in
            onChange(value, oldOnChange, newValue)
        }
        return SmartBind(value, composedOnChange)
    }
    
    func debounce(_ action: Value) {
        debouncer.send(action, realSend: onChange)
    }
    
    func flush() {
        debouncer.flush()
    }

    nonisolated static func ==(lhs: SmartBind<Value>, rhs: SmartBind<Value>) -> Bool {
        lhs.value == rhs.value
    }
}

extension View {
    /// Keep a `SmartBind` and `Bindable` in sync with each other
    func sync<Value: Equatable & Sendable>(_ bind: SmartBind<Value>, _ binding: Binding<Value>) -> some View {
        modifier(SmartBindModifier(bind: bind, binding: binding))
    }
}

struct SmartBindModifier<Value: Equatable & Sendable>: ViewModifier, Equatable {
    private let bind: SmartBind<Value>
    private let binding: Binding<Value>
    
    init(bind: SmartBind<Value>, binding: Binding<Value>) {
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
                guard old != new && new != bind.value else {
                    return
                }
                bind.onChange(new)
            }

    }
    
    nonisolated static func ==(lhs: SmartBindModifier<Value>, rhs: SmartBindModifier<Value>) -> Bool {
        lhs.bind == rhs.bind
    }
}
