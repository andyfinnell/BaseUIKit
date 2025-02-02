import SwiftUI

public struct BindingMap<Value, ToValue> {
    let get: @Sendable (Value) -> ToValue
    let set: @Sendable (Value, ToValue) -> Value
    
    public init(_ keyPath: WritableKeyPath<Value, ToValue> & Sendable) {
        get = { $0[keyPath: keyPath] }
        set = { value, toValue in
            var newValue = value
            newValue[keyPath: keyPath] = toValue
            return newValue
        }
    }
    
    public init(get: @Sendable @escaping (Value) -> ToValue, set: @Sendable @escaping (Value, ToValue) -> Value) {
        self.get = get
        self.set = set
    }
}

public extension Binding where Value: Sendable {
    func map<ToValue>(get: @Sendable @escaping (Value) -> ToValue, set: @Sendable @escaping (Value, ToValue) -> Value) -> Binding<ToValue> {
        Binding<ToValue>(
            get: { get(wrappedValue) },
            set: { wrappedValue = set(wrappedValue, $0) }
        )
    }
    
    func map<ToValue>(_ bindingMap: BindingMap<Value, ToValue>) -> Binding<ToValue> {
        map(get: bindingMap.get, set: bindingMap.set)
    }
}
