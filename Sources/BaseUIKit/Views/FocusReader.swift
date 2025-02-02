import SwiftUI

public struct FocusReader<Content: View, Value>: View {
    private var value: FocusedValue<Value>
    private let content: (Value?) -> Content
    
    public init(
        _ keyPath: KeyPath<FocusedValues, Value?>,
        @ViewBuilder content: @escaping (Value?) -> Content
    ) {
        value = FocusedValue(keyPath)
        self.content = content
    }
    
    public var body: some View {
        content(value.wrappedValue)
    }
}
