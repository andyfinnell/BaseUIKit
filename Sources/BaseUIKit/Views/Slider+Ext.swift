import SwiftUI

public extension Slider {
    init<C: RandomAccessCollection & Sendable>(
        sources: C,
        value: KeyPath<C.Element, Binding<Double>> & Sendable,
        in range: ClosedRange<Double>,
        step: Double.Stride = 1.0
    ) where Label == EmptyView, ValueLabel == EmptyView {
        self.init(
            value: Binding<Double>(sources: sources, value: value),
            in: range,
            step: step
        )
    }

}
