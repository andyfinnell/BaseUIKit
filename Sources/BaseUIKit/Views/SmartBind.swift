import SwiftUI

struct ExtraEmpty: Equatable, Sendable {}

/// This is an implementation type. AppStateKit doesn't like working in SwiftUI.Bindings
/// which wants to directly manipulate @State data, but to instead use closures to send
/// Actions back through the Engine. However, closures are unstable in Equatable, despite
/// the fact in practice, for a given View, they don't change.
///
/// Therefore this type wraps the current value and closure and only compares against
/// the current value
@MainActor
struct SmartBind<Value: Equatable & Sendable, Extra: Equatable & Sendable>: Equatable, DynamicProperty {
    @State private var debouncer = Debouncer<Value>()

    let value: Value
    let extra: Extra
    let onChange: (Value) -> Void
    
    init(_ value: Value, _ onChange: @escaping (Value) -> Void) where Extra == ExtraEmpty {
        self.value = value
        self.extra = ExtraEmpty()
        self.onChange = onChange
    }

    init(_ value: Value, _ extra: Extra, _ onChange: @escaping (Value) -> Void) {
        self.value = value
        self.extra = extra
        self.onChange = onChange
    }

    func map(onChange: @escaping (Value, (Value) -> Void, Value) -> Void) -> SmartBind<Value, Extra> {
        let oldOnChange = self.onChange
        let composedOnChange: (Value) -> Void = { newValue in
            onChange(value, oldOnChange, newValue)
        }
        return SmartBind(value, extra, composedOnChange)
    }
    
    func debounce(_ action: Value) {
        debouncer.send(action, realSend: onChange)
    }
    
    func flush() {
        debouncer.flush()
    }

    nonisolated static func ==(lhs: SmartBind<Value, Extra>, rhs: SmartBind<Value, Extra>) -> Bool {
        lhs.value == rhs.value && lhs.extra == rhs.extra
    }
}

extension View {
    /// Keep a `SmartBind` and `Bindable` in sync with each other
    func sync<Value: Equatable & Sendable, Extra: Equatable & Sendable>(_ bind: SmartBind<Value, Extra>, _ binding: Binding<Value>) -> some View {
        modifier(SmartBindModifier(bind: bind, binding: binding))
    }
}

struct SmartBindModifier<Value: Equatable & Sendable, Extra: Equatable & Sendable>: ViewModifier, Equatable {
    private let bind: SmartBind<Value, Extra>
    private let binding: Binding<Value>
    
    init(bind: SmartBind<Value, Extra>, binding: Binding<Value>) {
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
    
    nonisolated static func ==(lhs: SmartBindModifier<Value, Extra>, rhs: SmartBindModifier<Value, Extra>) -> Bool {
        lhs.bind == rhs.bind
    }
}
