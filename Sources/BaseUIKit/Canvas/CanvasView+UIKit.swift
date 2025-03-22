#if canImport(UIKit)
import UIKit
import SwiftUI

public struct CanvasView<ID: Hashable & Sendable>: UIViewRepresentable {
    private let database: CanvasDatabase<ID>
    private let onDimensionsChanged: ((CanvasViewDimensions) -> Void)?
    private let onEvent: ((Event) -> Void)?
    
    public init(
        database: CanvasDatabase<ID>,
        onDimensionsChanged: ((CanvasViewDimensions) -> Void)? = nil,
        onEvent: ((Event) -> Void)? = nil
    ) {
        self.database = database
        self.onDimensionsChanged = onDimensionsChanged
        self.onEvent = onEvent
    }
    
    public func makeUIView(context: Context) -> CanvasViewImpl<ID> {
        CanvasViewImpl(
            database: database,
            onDimensionsChanged: onDimensionsChanged,
            onEvent: onEvent
        )
    }
    
    public func updateUIView(_ nsView: CanvasViewImpl<ID>, context: Context) {
        nsView.database = database
        nsView.onDimensionsChanged = onDimensionsChanged
        nsView.onEvent = onEvent
    }
}

#endif
