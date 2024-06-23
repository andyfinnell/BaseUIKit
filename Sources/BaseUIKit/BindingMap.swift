import SwiftUI

public struct BindingMap<Value, ToValue> {
    let get: (Value) -> ToValue
    let set: (Value, ToValue) -> Value
    
    public init(_ keyPath: WritableKeyPath<Value, ToValue>) {
        get = { $0[keyPath: keyPath] }
        set = { value, toValue in
            var newValue = value
            newValue[keyPath: keyPath] = toValue
            return newValue
        }
    }
    
    public init(get: @escaping (Value) -> ToValue, set: @escaping (Value, ToValue) -> Value) {
        self.get = get
        self.set = set
    }
}

public extension Binding {
    func map<ToValue>(get: @escaping (Value) -> ToValue, set: @escaping (Value, ToValue) -> Value) -> Binding<ToValue> {
        Binding<ToValue>(
            get: { get(wrappedValue) },
            set: { wrappedValue = set(wrappedValue, $0) }
        )
    }
    
    func map<ToValue>(_ bindingMap: BindingMap<Value, ToValue>) -> Binding<ToValue> {
        map(get: bindingMap.get, set: bindingMap.set)
    }
}
