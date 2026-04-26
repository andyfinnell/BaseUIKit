#if canImport(AppKit)
import AppKit
import BaseKit
import SwiftUI

public struct CanvasView<ID: Hashable & Sendable>: NSViewRepresentable {
    private let database: CanvasDatabase<ID>
    private let onDimensionsChanged: ((CanvasViewDimensions) -> Void)?
    private let onEvent: ((Event) -> Void)?
    private let contextMenu: (@MainActor (Point) -> BaseUIKit.ContextMenu?)?

    public init(
        database: CanvasDatabase<ID>,
        onDimensionsChanged: ((CanvasViewDimensions) -> Void)? = nil,
        onEvent: ((Event) -> Void)? = nil,
        contextMenu: (@MainActor (Point) -> BaseUIKit.ContextMenu?)? = nil
    ) {
        self.database = database
        self.onDimensionsChanged = onDimensionsChanged
        self.onEvent = onEvent
        self.contextMenu = contextMenu
    }

    public func makeNSView(context: Context) -> CanvasViewImpl<ID> {
        CanvasViewImpl(
            database: database,
            onDimensionsChanged: onDimensionsChanged,
            onEvent: onEvent,
            contextMenuProvider: contextMenu
        )
    }

    public func updateNSView(_ nsView: CanvasViewImpl<ID>, context: Context) {
        nsView.db = database
        nsView.onDimensionsChanged = onDimensionsChanged
        nsView.onEvent = onEvent
        nsView.contextMenuProvider = contextMenu
    }
}

public struct CanvasScrollView<ID: Hashable & Sendable>: NSViewRepresentable {
    private let database: CanvasDatabase<ID>
    private let onDimensionsChanged: ((CanvasViewDimensions) -> Void)?
    private let onEvent: ((Event) -> Void)?
    private let onScrollPositionChanged: ((CGPoint) -> Void)?
    private let contextMenu: (@MainActor (Point) -> BaseUIKit.ContextMenu?)?

    public init(
        database: CanvasDatabase<ID>,
        onDimensionsChanged: ((CanvasViewDimensions) -> Void)? = nil,
        onEvent: ((Event) -> Void)? = nil,
        onScrollPositionChanged: ((CGPoint) -> Void)? = nil,
        contextMenu: (@MainActor (Point) -> BaseUIKit.ContextMenu?)? = nil
    ) {
        self.database = database
        self.onDimensionsChanged = onDimensionsChanged
        self.onEvent = onEvent
        self.onScrollPositionChanged = onScrollPositionChanged
        self.contextMenu = contextMenu
    }

    public func makeNSView(context: Context) -> CanvasScrollViewImpl<ID> {
        CanvasScrollViewImpl(
            database: database,
            onDimensionsChanged: onDimensionsChanged,
            onEvent: onEvent,
            onScrollPositionChanged: onScrollPositionChanged,
            contextMenuProvider: contextMenu
        )
    }

    public func updateNSView(_ nsView: CanvasScrollViewImpl<ID>, context: Context) {
        nsView.database = database
        nsView.onDimensionsChanged = onDimensionsChanged
        nsView.onEvent = onEvent
        nsView.onScrollPositionChanged = onScrollPositionChanged
        nsView.contextMenuProvider = contextMenu
    }
}

#endif
