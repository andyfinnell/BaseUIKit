import SwiftUI

public extension Binding where Value == String {
    init<C: RandomAccessCollection & Sendable>(
        sources: C,
        text: KeyPath<C.Element, Binding<String>> & Sendable
    ) {
        self.init(get: {
            sources.reduce("") { sum, element in
                let elementText = element[keyPath: text].wrappedValue
                if sum == "" {
                    return elementText
                } else if sum == elementText {
                    return sum
                } else {
                    return "-"
                }
            }
        }, set: { newValue, transaction in
            for element in sources {
                element[keyPath: text].wrappedValue = newValue
            }
        })
    }
}

public extension Binding where Value == Double {
    init<C: RandomAccessCollection & Sendable>(
        sources: C,
        value: KeyPath<C.Element, Binding<Double>> & Sendable
    ) {
        self.init(get: {
            sources.reduce(Double?.none) { sum, element in
                let elementValue = element[keyPath: value].wrappedValue
                if sum == nil {
                    return elementValue
                } else if let sum, sum == elementValue {
                    return sum
                } else {
                    return Double.infinity
                }
            } ?? 0.0
        }, set: { newValue, transaction in
            for element in sources {
                element[keyPath: value].wrappedValue = newValue
            }
        })
    }
}
