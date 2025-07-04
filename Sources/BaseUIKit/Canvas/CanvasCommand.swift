import BaseKit

public enum CanvasIndex: Hashable, Sendable {
    case last
    case at(Int)
}

extension CanvasIndex {
    func resolve<C: Collection>(for collection: C) -> Int {
        switch self {
        case .last:
            collection.count
        case let .at(i):
            i
        }
    }
}

public enum CanvasChange<ID: Hashable & Sendable>: Hashable, Sendable {
    case updateCursor(BaseUIKit.Cursor)
    
    case updateWidth(Double)
    case updateHeight(Double)
    case updateContentTransform(Transform)
    case updateBackgroundColor(Color?)
    
    case upsertLayer(Layer<ID>, at: CanvasIndex)
    case deleteLayer(ID)
    case reorderLayer(ID, to: CanvasIndex)

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
