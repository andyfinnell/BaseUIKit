import Foundation
import CoreGraphics
import BaseKit

@MainActor
protocol CanvasCoreViewDelegate: AnyObject {
    func invalidateCanvas()
    func invalidateRect(_ rect: CGRect)
    func invalidateContentSize()
    func invalidateCursor()
}

@MainActor
public final class CanvasDatabase<ID: Hashable & Sendable> {
    private var objectsInOrder = [any CanvasObject<ID>]()
    private var objectById = [ID: any CanvasObject<ID>]()
    
    var objectIDs: [ID] {
        objectsInOrder.map { $0.id }
    }
    
    var width: Double {
        didSet {
            if oldValue != width {
                invalidateContentSize()
            }
        }
    }
    
    var height: Double {
        didSet {
            if oldValue != height {
                invalidateContentSize()
            }
        }
    }
    
    public internal(set) var contentTransform: Transform {
        didSet {
            if oldValue != contentTransform {
                invalidateContentSize()
            }
        }
    }
    
    public internal(set) var backgroundColor: Color? = nil {
        didSet {
            if oldValue != backgroundColor {
                invalidate()
            }
        }
    }
    
    var renderTransparentBackground: Bool = true {
        didSet {
            if oldValue != renderTransparentBackground {
                invalidate()
            }
        }
    }
    
    weak var delegate: CanvasCoreViewDelegate?
    
    var screenDPI = 72.0
    
    var bounds: CGRect = .zero {
        didSet {
            invalidateContentSize()
        }
    }
    
    var zoom: CGFloat = 1.0 {
        didSet {
            invalidateContentSize()
        }
    }
    
    var viewContentSize: CGSize {
        let width = max(contentSize.width, bounds.width)
        let height = max(contentSize.height, bounds.height)
        return CGSize(width: width, height: height)
    }
    
    var contentSize: CGSize {
        CGSize(width: width * zoom, height: height * zoom)
    }
    
    private(set) var cursor = BaseUIKit.Cursor.default {
        didSet {
            if oldValue != cursor {
                delegate?.invalidateCursor()
            }
        }
    }
    
    public init(canvas: Canvas<ID>) {
        self.width = canvas.width
        self.height = canvas.height
        self.contentTransform = canvas.contentTransform
        self.backgroundColor = canvas.backgroundColor
        
        update(canvas)
    }
    
    func drawRect(_ rect: CGRect, into context: CGContext) {
        let intersectInViewCoords = rect.intersection(bounds)

        context.saveGState()
        context.clip(to: [intersectInViewCoords])
        drawPasteboard(in: context)
        
        // Switch to document coords
        let intersectInDocumentCoords = intersectInViewCoords.applying(transform.inverted())
        context.concatenate(transform)
        drawBackground(intersectInDocumentCoords, in: context)
        context.concatenate(contentAffineTransform)
        for object in objectsInOrder {
            object.draw(intersectInDocumentCoords, into: context)
        }
        
        context.restoreGState()
    }
        
    func update(_ canvas: Canvas<ID>) {
        width = canvas.width
        height = canvas.height
        contentTransform = canvas.contentTransform
        backgroundColor = canvas.backgroundColor
        
        let previousLayers = objectsInOrder.map { $0.layer }
        let diffs = canvas.layers.difference(from: previousLayers)
        let existing = objectById
        
        for diff in diffs {
            switch diff {
            case let .insert(offset: offset, element: layer, associatedWith: _):
                let canvasObject = existing[layer.id] ?? make(from: layer)
                insert(canvasObject, at: .at(offset))
                
            case let .remove(offset: _, element: layer, associatedWith: _):
                // If this is a move, `existing` will hold the object in memory
                //  until we're done
                remove(byID: layer.id)
            }
        }
        
        // Update existing
        for layer in canvas.layers {
            guard let object = existing[layer.id] else {
                continue
            }
            object.layer = layer
        }
    }
    
    func invalidate(_ object: any CanvasObject<ID>) {
        update(object)
    }
    
    func convertViewToDocument(_ pointInViewCoords: CGPoint) -> CGPoint {
        pointInViewCoords.applying(transform.inverted())
            .applying(contentAffineTransform)
    }
}

public extension CanvasDatabase {
    
    var dimensions: CanvasViewDimensions {
        CanvasViewDimensions(
            size: Size(width: width, height: height),
            screenDPI: screenDPI
        )
    }
    
    func perform(_ command: CanvasCommand<ID>) {
        for change in command.changes {
            apply(change)
        }
    }
    
    func layers(_ query: CanvasQuery, including predicate: (ID) -> Bool) -> [Layer<ID>] {
        switch query {
        case .all:
            allLayers(including: predicate)
        case let .underLocation(location):
            layerUnderLocation(location, including: predicate)
        case let .intersectingBounds(bounds):
            layersIntersectingBounds(bounds, including: predicate)
        case let .containingBounds(bounds):
            layersContainingBounds(bounds, including: predicate)
        }
    }
    
    func structurePaths(byIDs ids: [ID]) -> [BezierPath] {
        ids.compactMap { objectById[$0] }.map { $0.structurePath }
    }
}

private extension CanvasDatabase {
    func allLayers(including predicate: (ID) -> Bool) -> [Layer<ID>] {
        objectsInOrder.reversed().filter { predicate($0.id) }.map { $0.layer }
    }
    
    func layerUnderLocation(_ location: Point, including predicate: (ID) -> Bool) -> [Layer<ID>] {
        let cgLocation = location.toCG
        let foundObject = objectsInOrder.reversed().first { object in
            predicate(object.id) && object.hitTest(cgLocation)
        }
        if let foundObject {
            return [foundObject.layer]
        } else {
            return []
        }
    }
    
    func layersIntersectingBounds(_ bounds: Rect, including predicate: (ID) -> Bool) -> [Layer<ID>] {
        let cgBounds = bounds.toCG
        return objectsInOrder
            .filter { predicate($0.id) }
            .filter { $0.intersects(cgBounds) }
            .map { $0.layer }
    }

    func layersContainingBounds(_ bounds: Rect, including predicate: (ID) -> Bool) -> [Layer<ID>] {
        let cgBounds = bounds.toCG
        return objectsInOrder
            .filter { predicate($0.id) }
            .filter { $0.contained(by: cgBounds) }
            .map { $0.layer }
    }

    func apply(_ change: CanvasChange<ID>) {
        switch change {
        case let .updateCursor(cursor):
            self.cursor = cursor
            
        case let .updateWidth(width):
            self.width = width
            
        case let .updateHeight(height):
            self.height = height
            
        case let .updateContentTransform(contentTransform):
            self.contentTransform = contentTransform
            
        case let .updateBackgroundColor(color):
            self.backgroundColor = color
            
        case let .upsertLayer(layer, at: index):
            upsertLayer(layer, at: index)
            
        case let .deleteLayer(layerID):
            deleteLayer(by: layerID)
            
        case let .reorderLayer(fromID, to: toIndex):
            reorderLayer(fromID, to: toIndex)
        }
    }
    
    func upsertLayer(_ layer: Layer<ID>, at index: CanvasIndex) {
        if let existing = objectById[layer.id] {
            existing.layer = layer
        } else {
            let canvasObject = make(from: layer)
            insert(canvasObject, at: index)
        }
    }
    
    func deleteLayer(by layerID: ID) {
        remove(byID: layerID)
    }
    
    func reorderLayer(_ fromID: ID, to toIndex: CanvasIndex) {
        if let object = objectById[fromID] {
            invalidate(object)
        }
        if let fromIndex = objectsInOrder.firstIndex(where: { $0.id == fromID }) {
            objectsInOrder.reorder(from: fromIndex, to: resolve(toIndex))
        }
    }
    
    var contentOffset: CGPoint {
        // Center the content if there's excess space
        let x = max(bounds.width - (width * zoom), 0.0) / 2.0
        let y = max(bounds.height - (height * zoom), 0.0) / 2.0
        return CGPoint(x: x, y: y)
    }
    
    var transform: CGAffineTransform {
        CGAffineTransform.identity
            .scaledBy(x: zoom, y: zoom)
            .translatedBy(x: contentOffset.x, y: contentOffset.y)
    }
    
    var contentAffineTransform: CGAffineTransform {
        contentTransform.toCG
    }
        
    func drawPasteboard(in context: CGContext) {
        context.saveGState()
        context.setFillColor(Color.pasteboard.toCG)
        context.fill([bounds])
        context.restoreGState()
    }
    
    func drawBackground(_ dirtyRect: CGRect, in context: CGContext) {
        let canvasRect = CGRect(x: 0, y: 0, width: width, height: height)
        let dirtyCanvasRect = canvasRect.intersection(dirtyRect)
        context.saveGState()
        if let backgroundColor {
            backgroundColor.setFill(in: context)
            context.fill(dirtyCanvasRect)
        } else {
            if renderTransparentBackground {
                context.drawCheckboard(dirtyCanvasRect)
            } else {
                context.clear(dirtyCanvasRect)
            }
        }
        context.restoreGState()
    }
    
    func invalidate() {
        delegate?.invalidateCanvas()
    }
    
    func invalidate(_ rect: CGRect) {
        let invalidRect = rect
            .applying(contentAffineTransform.inverted())
            .applying(transform)
        delegate?.invalidateRect(invalidRect)
    }
    
    func invalidateContentSize() {
        delegate?.invalidateContentSize()
        delegate?.invalidateCanvas()
    }
    
    func insert(_ object: any CanvasObject<ID>, at index: CanvasIndex) {
        let trueIndex = resolve(index)
        objectsInOrder.insert(object, at: trueIndex)
        objectById[object.id] = object
        object.canvas = self
        invalidate(object.willDrawRect)
    }
    
    func resolve(_ index: CanvasIndex) -> Int {
        index.resolve(for: objectsInOrder)
    }
    
    func remove(byID id: ID) {
        guard let object = objectById[id] else {
            return
        }
        // TODO: should CanvasObject store it's index for perfomance reasons?
        let index = objectsInOrder.firstIndex(where: { $0.id == id })

        invalidate(object.didDrawRect)
        
        if let index {
            objectsInOrder.remove(at: index)
        }
        objectById.removeValue(forKey: id)
    }
        
    func update(_ object: any CanvasObject<ID>) {
        invalidate(object.didDrawRect)
        invalidate(object.willDrawRect)
    }
    
    func make(from layer: Layer<ID>) -> any CanvasObject<ID> {
        switch layer {
        case let .image(imageLayer):
            CanvasImage(layer: imageLayer)
        case let .text(textLayer):
            CanvasText(layer: textLayer)
        case let .path(pathLayer):
            CanvasPath(layer: pathLayer)
        }
    }
}
