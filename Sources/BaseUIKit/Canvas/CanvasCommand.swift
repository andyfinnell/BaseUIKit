import BaseKit

/// Where to place a layer in the canvas. `parent == nil` targets the
/// top-level z-ordered list; a non-nil `parent` references a `GroupLayer`
/// and the position applies inside that group's children. `reorderLayer`
/// with a `parent` different from the layer's current parent re-parents
/// the layer atomically.
public struct CanvasIndex<ID: Hashable & Sendable>: Hashable, Sendable {
    public enum Position: Hashable, Sendable {
        case last
        case at(Int)
    }

    public let parent: ID?
    public let position: Position

    public init(parent: ID? = nil, position: Position) {
        self.parent = parent
        self.position = position
    }
}

public extension CanvasIndex {
    /// Append to the top-level list.
    static var last: CanvasIndex { CanvasIndex(position: .last) }

    /// Insert at a specific position in the top-level list.
    static func at(_ position: Int) -> CanvasIndex {
        CanvasIndex(position: .at(position))
    }

    /// Append to the given group's children.
    static func last(in parent: ID) -> CanvasIndex {
        CanvasIndex(parent: parent, position: .last)
    }

    /// Insert at a specific position within the given group's children.
    static func at(_ position: Int, in parent: ID) -> CanvasIndex {
        CanvasIndex(parent: parent, position: .at(position))
    }
}

extension CanvasIndex {
    func resolve<C: Collection>(for collection: C) -> Int {
        switch position {
        case .last:
            collection.count
        case let .at(i):
            min(i, collection.count)
        }
    }
}

public enum CanvasChange<ID: Hashable & Sendable>: Hashable, Sendable {
    case updateCursor(BaseUIKit.Cursor)

    case updateWidth(Double)
    case updateHeight(Double)
    case updateContentTransform(Transform)
    case updateBackgroundColor(Color?)

    case upsertLayer(Layer<ID>, at: CanvasIndex<ID>)
    case deleteLayer(ID)
    case reorderLayer(ID, to: CanvasIndex<ID>)

    case beginZooming
    case endZooming
    case zoomTo(Double, centeredAt: Point?)

    case updateScrollPosition(Point)
}

public struct CanvasCommand<ID: Hashable & Sendable>: Hashable, Sendable {
    public let changes: [CanvasChange<ID>]
    
    public init(changes: [CanvasChange<ID>]) {
        self.changes = changes
    }
    
    public init(_ changes: CanvasChange<ID>...) {
        self.changes = changes
    }
}
