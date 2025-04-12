import Foundation
import CoreGraphics
import BaseKit
import Synchronization

@MainActor
protocol CanvasCoreViewDelegate: AnyObject {
    func invalidate(_ invalidations: Set<CanvasInvalidation>)
}

public final class CanvasDatabase<ID: Hashable & Sendable>: Sendable {
    private let memberData: Mutex<MemberData>
            
    public init(canvas: Canvas<ID>) {
        memberData = Mutex(
            MemberData(
                width: canvas.width,
                height: canvas.height,
                contentTransform: canvas.contentTransform,
                backgroundColor: canvas.backgroundColor
            )
        )
        update(canvas)
    }
    
    func drawRect(_ rect: CGRect, into context: CGContext) {
        memberData.withLock {
            locked_drawRect(&$0, rect, into: context)
        }
    }
        
    func update(_ canvas: Canvas<ID>) {
        let (invalidates, delegate) = memberData.withLock {
            var invalidates = Set<CanvasInvalidation>()
            locked_update(&$0, canvas, invalidates: &invalidates)
            return (invalidates, $0.delegate)
        }
        Task { @MainActor in
            delegate.invalidate(invalidates)
        }
    }
        
    func convertViewToDocument(_ pointInViewCoords: CGPoint) -> CGPoint {
        memberData.withLock {
            locked_convertViewToDocument(&$0, pointInViewCoords)
        }
    }
    
    @MainActor
    func setDelegate(_ delegate: CanvasCoreViewDelegate?) {
        let realDelegate = Delegate(
            invalidate: { @MainActor [weak delegate] invalidationSet in
                delegate?.invalidate(invalidationSet)
            }
        )
        memberData.withLock {
            $0.delegate = realDelegate
        }
    }
    
    var bounds: CGRect {
        memberData.withLock { $0.bounds }
    }
    
    func setBounds(_ newValue: CGRect) {
        let (invalidates, delegate) = memberData.withLock {
            let didChange = $0.bounds != newValue
            $0.bounds = newValue
            var invalidates = Set<CanvasInvalidation>()
            if didChange {
                locked_invalidateContentSize(&$0, into: &invalidates)
            }
            return (invalidates, $0.delegate)
        }
        Task { @MainActor in
            delegate.invalidate(invalidates)
        }
    }
    
    var contentSize: CGSize {
        memberData.withLock {
            CGSize(width: $0.width * $0.zoom, height: $0.height * $0.zoom)
        }
    }
    
    var cursor: BaseUIKit.Cursor {
        memberData.withLock {
            $0.cursor
        }
    }
}

public extension CanvasDatabase {
    
    var dimensions: CanvasViewDimensions {
        memberData.withLock {
            locked_dimensions(&$0)
        }
    }
        
    func perform(_ command: CanvasCommand<ID>) {
        let (invalidates, delegate) = memberData.withLock {
            var invalidates = Set<CanvasInvalidation>()
            locked_perform(&$0, command, invalidates: &invalidates)
            return (invalidates, $0.delegate)
        }
        Task { @MainActor in
            delegate.invalidate(invalidates)
        }
    }
    
    func layers(_ query: CanvasQuery, including predicate: (ID) -> Bool) -> [Layer<ID>] {
        memberData.withLock {
            locked_layers(&$0, query, including: predicate)
        }
    }
    
    func structurePaths(byIDs ids: [ID]) -> [BezierPath] {
        memberData.withLock {
            locked_structurePaths(&$0, byIDs: ids)
        }
    }
    
    func effectBounds(ofIDs ids: [ID]) -> Rect {
        memberData.withLock {
            locked_effectBounds(&$0, ofIDs: ids)
        }
    }
}

private extension CanvasDatabase {
    struct Generated {
        let basedOnLayerID: ID
        let layerIDs: [ID]
    }

    struct Delegate: Sendable {
        var invalidate: @MainActor (Set<CanvasInvalidation>) -> Void = {_ in }
    }
    
    struct MemberData: Sendable {
        var objectsInOrder = [any CanvasObject<ID>]()
        var objectById = [ID: any CanvasObject<ID>]()
        var generatedLayersByComputedID = [ID: Generated]() // ComputedLayer.id -> generated IDs
        var computedLayersBasedOnID = [ID: [ComputedLayer<ID>]]() // Dependent layer id -> ComputedLayer
        var width: Double
        var height: Double
        var contentTransform: Transform
        var backgroundColor: Color? = nil
        var renderTransparentBackground: Bool = true
        var screenDPI = 72.0
        var bounds: CGRect = .zero
        var zoom: CGFloat = 1.0
        var cursor = BaseUIKit.Cursor.default
        var delegate = Delegate()
    }
    
    func locked_dimensions(_ memberData: inout MemberData) -> CanvasViewDimensions {
        CanvasViewDimensions(
            size: Size(width: memberData.width, height: memberData.height),
            screenDPI: memberData.screenDPI
        )
    }
        
    func locked_perform(_ memberData: inout MemberData, _ command: CanvasCommand<ID>, invalidates: inout Set<CanvasInvalidation>) {
        for change in command.changes {
            locked_apply(&memberData, change, invalidates: &invalidates)
        }
    }
    
    func locked_layers(_ memberData: inout MemberData, _ query: CanvasQuery, including predicate: (ID) -> Bool) -> [Layer<ID>] {
        switch query {
        case .all:
            locked_allLayers(&memberData, including: predicate)
        case let .underLocation(location):
            locked_layerUnderLocation(&memberData, location, including: predicate)
        case let .intersectingBounds(bounds):
            locked_layersIntersectingBounds(&memberData, bounds, including: predicate)
        case let .containingBounds(bounds):
            locked_layersContainingBounds(&memberData, bounds, including: predicate)
        }
    }
    
    func locked_structurePaths(_ memberData: inout MemberData, byIDs ids: [ID]) -> [BezierPath] {
        ids.compactMap { memberData.objectById[$0] }.map { $0.structurePath }
    }
    
    func locked_effectBounds(_ memberData: inout MemberData, ofIDs ids: [ID]) -> Rect {
        let cgRect = ids.compactMap { memberData.objectById[$0] }
            .map { $0.willDrawRect }
            .reduce(CGRect.zero) { sum, rect in
                (sum == .zero) ? rect : sum.union(rect)
            }
        return Rect(cgRect)
    }

    func locked_drawRect(_ memberData: inout MemberData, _ rect: CGRect, into context: CGContext) {
        let intersectInViewCoords = rect.intersection(memberData.bounds)

        context.saveGState()
        context.clip(to: [intersectInViewCoords])
        locked_drawPasteboard(&memberData, in: context)
        
        // Switch to document coords
        let intersectInDocumentCoords = intersectInViewCoords
            .applying(locked_transform(&memberData).inverted())
        context.concatenate(locked_transform(&memberData))
        locked_drawBackground(&memberData, intersectInDocumentCoords, in: context)
        context.concatenate(locked_contentAffineTransform(&memberData))
        for object in memberData.objectsInOrder {
            object.draw(intersectInDocumentCoords, into: context, atScale: memberData.zoom)
        }
        
        context.restoreGState()
    }
        
    func locked_update(_ memberData: inout MemberData, _ canvas: Canvas<ID>, invalidates: inout Set<CanvasInvalidation>) {
        if memberData.width != canvas.width {
            memberData.width = canvas.width
            locked_invalidateContentSize(&memberData, into: &invalidates)
        }
        if memberData.height != canvas.height {
            memberData.height = canvas.height
            locked_invalidateContentSize(&memberData, into: &invalidates)
        }
        if memberData.contentTransform != canvas.contentTransform {
            memberData.contentTransform = canvas.contentTransform
            locked_invalidateContentSize(&memberData, into: &invalidates)
        }
        if memberData.backgroundColor != canvas.backgroundColor {
            memberData.backgroundColor = canvas.backgroundColor
            invalidates.insert(.invalidateCanvas)
        }
        
        let previousLayers = memberData.objectsInOrder.map { $0.layer }
        let canvasLayers = locked_flattenCanvasLayers(&memberData, canvas, invalidates: &invalidates)
        let diffs = canvasLayers.difference(from: previousLayers)
        // Order is important here; flattenCanvasLayers can add to objectById
        let existing = memberData.objectById
        
        for diff in diffs {
            switch diff {
            case let .insert(offset: offset, element: layer, associatedWith: _):
                guard let canvasObject = existing[layer.id] ?? make(from: layer) else {
                    break
                }
                locked_insert(&memberData, canvasObject, at: .at(offset), invalidates: &invalidates)
                
            case let .remove(offset: _, element: layer, associatedWith: _):
                // If this is a move, `existing` will hold the object in memory
                //  until we're done
                locked_remove(&memberData, byID: layer.id, invalidates: &invalidates)
            }
        }
        
        // Update existing
        for layer in canvasLayers {
            guard let object = existing[layer.id] else {
                continue
            }
            locked_transformLayerInvalidateRect(
                &memberData,
                from: object.updateLayer(layer),
                into: &invalidates
            )
        }
        
        // We've already run all computedLayers back in flattenCanvasLayers
        //  so no need to handle them here.
    }
    
    func locked_invalidateObject(_ memberData: inout MemberData, _ object: any CanvasObject<ID>, into invalidates: inout Set<CanvasInvalidation>) {
        locked_invalidateRect(&memberData, object.didDrawRect, into: &invalidates)
        locked_invalidateRect(&memberData, object.willDrawRect, into: &invalidates)
    }
    
    func locked_convertViewToDocument(_ memberData: inout MemberData, _ pointInViewCoords: CGPoint) -> CGPoint {
        pointInViewCoords.applying(locked_transform(&memberData).inverted())
            .applying(locked_contentAffineTransform(&memberData))
    }

    func locked_allLayers(_ memberData: inout MemberData, including predicate: (ID) -> Bool) -> [Layer<ID>] {
        memberData.objectsInOrder.reversed().filter { predicate($0.id) }.map { $0.layer }
    }
    
    func locked_layerUnderLocation(
        _ memberData: inout MemberData,
        _ location: Point,
        including predicate: (ID) -> Bool
    ) -> [Layer<ID>] {
        let cgLocation = location.toCG
        let foundObject = memberData.objectsInOrder.reversed().first { object in
            predicate(object.id) && object.hitTest(cgLocation)
        }
        if let foundObject {
            return [foundObject.layer]
        } else {
            return []
        }
    }
    
    func locked_layersIntersectingBounds(_ memberData: inout MemberData, _ bounds: Rect, including predicate: (ID) -> Bool) -> [Layer<ID>] {
        let cgBounds = bounds.toCG
        return memberData.objectsInOrder
            .filter { predicate($0.id) }
            .filter { $0.intersects(cgBounds) }
            .map { $0.layer }
    }

    func locked_layersContainingBounds(_ memberData: inout MemberData, _ bounds: Rect, including predicate: (ID) -> Bool) -> [Layer<ID>] {
        let cgBounds = bounds.toCG
        return memberData.objectsInOrder
            .filter { predicate($0.id) }
            .filter { $0.contained(by: cgBounds) }
            .map { $0.layer }
    }

    func locked_apply(_ memberData: inout MemberData, _ change: CanvasChange<ID>, invalidates: inout Set<CanvasInvalidation>) {
        switch change {
        case let .updateCursor(cursor):
            if memberData.cursor != cursor {
                memberData.cursor = cursor
                invalidates.insert(.invalidateCursor)
            }
            
        case let .updateWidth(width):
            if memberData.width != width {
                memberData.width = width
                locked_invalidateContentSize(&memberData, into: &invalidates)
            }
            
        case let .updateHeight(height):
            if memberData.height != height {
                memberData.height = height
                locked_invalidateContentSize(&memberData, into: &invalidates)
            }
            
        case let .updateZoom(zoom):
            if memberData.zoom != zoom {
                memberData.zoom = zoom
                locked_invalidateContentSize(&memberData, into: &invalidates)
            }
            
        case let .updateContentTransform(contentTransform):
            if memberData.contentTransform != contentTransform {
                memberData.contentTransform = contentTransform
                locked_invalidateContentSize(&memberData, into: &invalidates)
            }
            
        case let .updateBackgroundColor(color):
            if memberData.backgroundColor != color {
                memberData.backgroundColor = color
                invalidates.insert(.invalidateCanvas)
            }
            
        case let .upsertLayer(layer, at: index):
            locked_upsertLayer(&memberData, layer, at: index, invalidates: &invalidates)
            
        case let .deleteLayer(layerID):
            locked_deleteLayer(&memberData, by: layerID, invalidates: &invalidates)
            
        case let .reorderLayer(fromID, to: toIndex):
            locked_reorderLayer(&memberData, fromID: fromID, to: toIndex, invalidates: &invalidates)
        }
    }
    
    func locked_upsertLayer(
        _ memberData: inout MemberData,
        _ layer: Layer<ID>,
        at index: CanvasIndex,
        invalidates: inout Set<CanvasInvalidation>
    ) {
        if let existing = memberData.objectById[layer.id] {
            locked_transformLayerInvalidateRect(
                &memberData,
                from: existing.updateLayer(layer),
                into: &invalidates
            )
            locked_updateComputedLayers(&memberData, basedOn: layer, invalidates: &invalidates)
        } else if let canvasObject = make(from: layer) {
            locked_insert(&memberData, canvasObject, at: index, invalidates: &invalidates)
        } else if case let .computed(computed) = layer,
                  let basedOn = memberData.objectById[computed.basedOn] {
            let newLayers = computed.factory(
                basedOn.layer,
                withContext: LayerFactoryContext(structurePath: basedOn.structurePath)
            )
            locked_upsertComputedLayers(&memberData, newLayers, for: computed, at: index, invalidates: &invalidates)
            
            // Insert into the computed layers so it can be re-run later
            if let existing = memberData.computedLayersBasedOnID[computed.basedOn] {
                if !existing.contains(where: { $0.id == computed.id }) {
                    memberData.computedLayersBasedOnID[computed.basedOn] = existing + [computed]
                }
            } else {
                memberData.computedLayersBasedOnID[computed.basedOn] = [computed]
            }
        }
    }
    
    func locked_updateComputedLayers(
        _ memberData: inout MemberData,
        basedOn layer: Layer<ID>,
        invalidates: inout Set<CanvasInvalidation>
    ) {
        guard let computers = memberData.computedLayersBasedOnID[layer.id] else {
            return
        }

        for computer in computers {
            locked_updateComputedLayer(&memberData, computer, invalidates: &invalidates)
        }
    }
    
    func locked_updateComputedLayer(
        _ memberData: inout MemberData,
        _ computedLayer: ComputedLayer<ID>,
        invalidates: inout Set<CanvasInvalidation>
    ) {
        guard let basedOn = memberData.objectById[computedLayer.basedOn] else {
            return
        }
        let newLayers = computedLayer.factory(
            basedOn.layer,
            withContext: LayerFactoryContext(structurePath: basedOn.structurePath)
        )
        
        locked_upsertComputedLayers(&memberData, newLayers, for: computedLayer, at: nil, invalidates: &invalidates)
    }
    
    func locked_upsertComputedLayers(
        _ memberData: inout MemberData,
        _ computedLayers: [Layer<ID>],
        for layer: ComputedLayer<ID>,
        at index: CanvasIndex?,
        invalidates: inout Set<CanvasInvalidation>
    ) {
        let previousObjects = memberData
            .generatedLayersByComputedID[layer.id]?
            .layerIDs
            .compactMap { memberData.objectById[$0] } ?? []
        let previousLayers = previousObjects.map { $0.layer }
        let diffs = computedLayers.difference(from: previousLayers)
        let existing = memberData.objectById
        let baseIndex = locked_resolve(&memberData, index, usingExistingObjects: previousObjects)
        
        for diff in diffs {
            switch diff {
            case let .insert(offset: offset, element: layer, associatedWith: _):
                guard let canvasObject = existing[layer.id] ?? make(from: layer) else {
                    break
                }
                locked_insert(&memberData, canvasObject, at: .at(baseIndex + offset), invalidates: &invalidates)
                
            case let .remove(offset: _, element: layer, associatedWith: _):
                // If this is a move, `existing` will hold the object in memory
                //  until we're done
                locked_remove(&memberData, byID: layer.id, invalidates: &invalidates)
            }
        }
        
        // Update existing
        for layer in computedLayers {
            guard let object = existing[layer.id] else {
                continue
            }
            locked_transformLayerInvalidateRect(
                &memberData,
                from: object.updateLayer(layer),
                into: &invalidates
            )
        }
        
        memberData.generatedLayersByComputedID[layer.id] = Generated(
            basedOnLayerID: layer.basedOn,
            layerIDs: computedLayers.map(\.id)
        )
    }
    
    func locked_flattenCanvasLayers(
        _ memberData: inout MemberData,
        _ canvas: Canvas<ID>,
        invalidates: inout Set<CanvasInvalidation>
    ) -> [Layer<ID>] {
        let newLayersById = canvas.layers.reduce(into: [ID: Layer<ID>]()) {
            $0[$1.id] = $1
        }
        let canvasLayers = canvas.layers.flatMap {
            if case let .computed(computed) = $0 {
                return locked_flattenComputedLayer(&memberData, computed, using: newLayersById, invalidates: &invalidates)
            } else {
                return [$0]
            }
        }
        
        // Delete the old computed layers
        let deletedComputedLayerIDs = memberData.generatedLayersByComputedID.keys.filter { newLayersById[$0] == nil }
        for id in deletedComputedLayerIDs {
            locked_deleteLayer(&memberData, by: id, invalidates: &invalidates)
        }
        
        return canvasLayers
    }
    
    func locked_flattenComputedLayer(
        _ memberData: inout MemberData,
        _ computed: ComputedLayer<ID>,
        using layersByID: [ID: Layer<ID>],
        invalidates: inout Set<CanvasInvalidation>
    ) -> [Layer<ID>] {
        guard let basedLayer = layersByID[computed.basedOn] else {
            return []
        }
        
        // We need the basedLayer's canvasObject, which may or may or may not exist
        //  and may or may not be up-to-date
        guard let basedObject = memberData.objectById[basedLayer.id] ?? make(from: basedLayer) else {
            return []
        }
        locked_transformLayerInvalidateRect(
            &memberData,
            from: basedObject.updateLayer(basedLayer),
            into: &invalidates
        )
        memberData.objectById[basedLayer.id] = basedObject // in case we just created it

        let computedLayers = computed.factory(
            basedLayer,
            withContext: LayerFactoryContext(structurePath: basedObject.structurePath)
        )
        memberData.generatedLayersByComputedID[computed.id] = Generated(
            basedOnLayerID: basedLayer.id,
            layerIDs: computedLayers.map(\.id)
        )
        
        memberData.computedLayersBasedOnID[basedLayer.id, default: []].append(computed)
        
        return computedLayers
    }

    func locked_deleteLayer(_ memberData: inout MemberData, by layerID: ID, invalidates: inout Set<CanvasInvalidation>) {
        if let generated = memberData.generatedLayersByComputedID[layerID] {
            locked_removeComputed(&memberData, byID: layerID, generated: generated, invalidates: &invalidates)
        } else {
            locked_remove(&memberData, byID: layerID, invalidates: &invalidates)
        }
    }
    
    func locked_reorderLayer(_ memberData: inout MemberData, fromID: ID, to toIndex: CanvasIndex, invalidates: inout Set<CanvasInvalidation>) {
        if let object = memberData.objectById[fromID] {
            locked_invalidateObject(&memberData, object, into: &invalidates)
        }
        if let fromIndex = memberData.objectsInOrder.firstIndex(where: { $0.id == fromID }) {
            memberData.objectsInOrder.reorder(from: fromIndex, to: locked_resolve(&memberData, toIndex))
        }
    }
    
    func locked_contentOffset(_ memberData: inout MemberData) -> CGPoint {
        // Center the content if there's excess space
        let x = max(memberData.bounds.width - (memberData.width * memberData.zoom), 0.0) / 2.0
        let y = max(memberData.bounds.height - (memberData.height * memberData.zoom), 0.0) / 2.0
        return CGPoint(x: x, y: y)
    }
    
    func locked_transform(_ memberData: inout MemberData) -> CGAffineTransform {
        let contentOffset = locked_contentOffset(&memberData)
        return CGAffineTransform.identity
            .scaledBy(x: memberData.zoom, y: memberData.zoom)
            .translatedBy(x: contentOffset.x, y: contentOffset.y)
    }
    
    func locked_contentAffineTransform(_ memberData: inout MemberData) -> CGAffineTransform {
        memberData.contentTransform.toCG
    }
        
    func locked_drawPasteboard(_ memberData: inout MemberData, in context: CGContext) {
        context.saveGState()
        context.setFillColor(Color.pasteboard.toCG)
        context.fill([memberData.bounds])
        context.restoreGState()
    }
    
    func locked_drawBackground(_ memberData: inout MemberData, _ dirtyRect: CGRect, in context: CGContext) {
        let canvasRect = CGRect(x: 0, y: 0, width: memberData.width, height: memberData.height)
        let dirtyCanvasRect = canvasRect.intersection(dirtyRect)
        context.saveGState()
        if let backgroundColor = memberData.backgroundColor {
            backgroundColor.setFill(in: context)
            context.fill(dirtyCanvasRect)
        } else {
            if memberData.renderTransparentBackground {
                context.drawCheckboard(dirtyCanvasRect)
            } else {
                context.clear(dirtyCanvasRect)
            }
        }
        context.restoreGState()
    }
    
    func locked_invalidateCanvas(_ memberData: inout MemberData, into invalids: inout Set<CanvasInvalidation>) {
        invalids.insert(.invalidateCanvas)
    }
    
    func locked_transformLayerInvalidateRect(
        _ memberData: inout MemberData,
        from inputs: Set<CanvasInvalidation>,
        into invalids: inout Set<CanvasInvalidation>
    ) {
        for input in inputs {
            switch input {
            case .invalidateCanvas,
                    .invalidateContentSize,
                    .invalidateCursor:
                invalids.insert(input)
                
            case let .invalidateRect(rawRect):
                locked_invalidateRect(&memberData, rawRect, into: &invalids)
            }
        }
    }
    
    func locked_invalidateRect(
        _ memberData: inout MemberData,
        _ rect: CGRect,
        into invalids: inout Set<CanvasInvalidation>
    ) {
        let invalidRect = rect
            .applying(locked_contentAffineTransform(&memberData).inverted())
            .applying(locked_transform(&memberData))
        invalids.insert(.invalidateRect(invalidRect))
    }
    
    func locked_invalidateContentSize(_ memberData: inout MemberData, into invalids: inout Set<CanvasInvalidation>) {
        invalids.insert(.invalidateContentSize)
        invalids.insert(.invalidateCanvas)
    }
    
    func locked_insert(
        _ memberData: inout MemberData,
        _ object: any CanvasObject<ID>,
        at index: CanvasIndex,
        invalidates: inout Set<CanvasInvalidation>
    ) {
        let trueIndex = locked_resolve(&memberData, index)
        memberData.objectsInOrder.insert(object, at: trueIndex)
        memberData.objectById[object.id] = object
        locked_invalidateRect(&memberData, object.willDrawRect, into: &invalidates)
    }
    
    func locked_resolve(_ memberData: inout MemberData, _ index: CanvasIndex?, usingExistingObjects existingObjects: [any CanvasObject]) -> Int {
        if let index {
            return locked_resolve(&memberData, index)
        } else if let firstObject = existingObjects.first,
                  let firstObjectIndex = memberData.objectsInOrder.firstIndex(where: { $0 === firstObject }) {
            return firstObjectIndex
        } else {
            return locked_resolve(&memberData, .last)
        }
    }
    
    func locked_resolve(_ memberData: inout MemberData, _ index: CanvasIndex) -> Int {
        index.resolve(for: memberData.objectsInOrder)
    }
    
    func locked_remove(_ memberData: inout MemberData, byID id: ID, invalidates: inout Set<CanvasInvalidation>) {
        locked_removeConcrete(&memberData, byID: id, invalidates: &invalidates)
    }
        
    func locked_removeComputed(_ memberData: inout MemberData, byID id: ID, generated: Generated, invalidates: inout Set<CanvasInvalidation>) {
        for generatedID in generated.layerIDs {
            locked_removeConcrete(&memberData, byID: generatedID, invalidates: &invalidates)
        }
        memberData.generatedLayersByComputedID.removeValue(forKey: id)
        if let computedLayers = memberData.computedLayersBasedOnID[generated.basedOnLayerID] {
            memberData.computedLayersBasedOnID[generated.basedOnLayerID] = computedLayers.filter { $0.id != id }
        }
    }

    func locked_removeConcrete(_ memberData: inout MemberData, byID id: ID, invalidates: inout Set<CanvasInvalidation>) {
        guard let object = memberData.objectById[id] else {
            return
        }
        // TODO: should CanvasObject store it's index for perfomance reasons?
        let index = memberData.objectsInOrder.firstIndex(where: { $0.id == id })

        locked_invalidateRect(&memberData, object.didDrawRect, into: &invalidates)
        
        if let index {
            memberData.objectsInOrder.remove(at: index)
        }
        memberData.objectById.removeValue(forKey: id)
    }
    
    func make(from layer: Layer<ID>) -> (any CanvasObject<ID>)? {
        switch layer {
        case let .image(imageLayer):
            CanvasImage(layer: imageLayer)
        case let .text(textLayer):
            CanvasText(layer: textLayer)
        case let .path(pathLayer):
            CanvasPath(layer: pathLayer)
        case .computed:
            nil
        }
    }
}
