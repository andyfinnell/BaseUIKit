import Foundation
import CoreGraphics
import BaseKit
import Synchronization

@MainActor
protocol CanvasCoreViewDelegate: AnyObject {
    func invalidate(_ invalidations: Set<CanvasInvalidation>)
}

public final class CanvasDatabase<ID: Hashable & Sendable>: Sendable {
    private let renderingCache = RenderingCache()
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

    /// Controls whether the canvas paints a checkerboard transparency
    /// indicator behind areas without an explicit background color. The
    /// editor wants the checkerboard for visibility; tests and exports
    /// usually want it off so the canvas's true alpha shows through.
    public func setRenderTransparentBackgroundIndicator(_ value: Bool) {
        memberData.withLock { $0.renderTransparentBackground = value }
    }
        
    func update(_ canvas: Canvas<ID>) {
        let (invalidates, delegate) = memberData.withLock {
            var invalidates = Set<CanvasInvalidation>()
            locked_update(&$0, canvas, invalidates: &invalidates)
            return (invalidates, $0.delegate)
        }
        dispatchInvalidations(invalidates, to: delegate)
    }
        
    public func convertViewToDocument(_ pointInViewCoords: CGPoint) -> CGPoint {
        memberData.withLock {
            locked_convertViewToDocument(&$0, pointInViewCoords)
        }
    }

    public func convertDocumentToView(_ pointInDocumentCoords: CGPoint) -> CGPoint {
        memberData.withLock {
            locked_convertDocumentToView(&$0, pointInDocumentCoords)
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
        dispatchInvalidations(invalidates, to: delegate)
    }
    
    public var visibleSize: CGSize {
        memberData.withLock { $0.visibleSize }
    }
    
    func setVisibleSize(_ newValue: CGSize) {
        let (invalidates, delegate) = memberData.withLock {
            let didChange = $0.visibleSize != newValue
            $0.visibleSize = newValue
            var invalidates = Set<CanvasInvalidation>()
            if didChange {
                locked_invalidateContentSize(&$0, into: &invalidates)
            }
            return (invalidates, $0.delegate)
        }
        dispatchInvalidations(invalidates, to: delegate)
    }

    public var visibleOffset: CGPoint {
        get { memberData.withLock { $0.visibleOffset } }
        set { setVisibleOffset(newValue) }
    }
    
    var contentSize: CGSize {
        memberData.withLock { locked_contentSize(&$0) }
    }
    
    var cursor: BaseUIKit.Cursor {
        memberData.withLock {
            $0.cursor
        }
    }
    
    var toEvent: EventCanvas {
        memberData.withLock {
            locked_toEvent(&$0)
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
        dispatchInvalidations(invalidates, to: delegate)
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

    /// Returns the y-flipped, un-transformed glyph outline for a text layer,
    /// or `nil` if the ID doesn't refer to a text layer.
    func outlinePath(byID id: ID) -> BezierPath? {
        memberData.withLock {
            $0.objectById[id]?.outlinePath
        }
    }

    func effectBounds(ofIDs ids: [ID]) -> Rect {
        memberData.withLock {
            locked_effectBounds(&$0, ofIDs: ids)
        }
    }

    /// Samples the pixel color from an image layer at the given canvas-space location.
    /// Returns `nil` if the layer is not an image, the location is outside the image bounds,
    /// or the image data cannot be decoded.
    func sampleImageColor(at location: Point, in layerID: ID) -> Color? {
        memberData.withLock { memberData in
            memberData.objectById[layerID]?.sampleColor(at: location.toCG)
        }
    }

    /// Draws only the layers matching `ids` into the given context.
    /// The context should already be configured with the desired coordinate transform.
    func drawElements(ids: Set<ID>, in rect: CGRect, into context: CGContext, atScale scale: CGFloat) {
        memberData.withLock { memberData in
            locked_drawElements(&memberData, ids: ids, in: rect, into: context, atScale: scale)
        }
    }

    /// Returns the character index in the text layer closest to the given point.
    /// The point is in content/object space (same coordinate space as `CanvasQuery.underLocation`).
    /// Returns nil if the ID does not refer to a text layer.
    func textIndex(at point: Point, in layerID: ID) -> TextPosition? {
        memberData.withLock {
            locked_textIndex(&$0, at: point, in: layerID)
        }
    }

    /// Returns the visual bounds of the given text range within the text layer,
    /// in content/object space. Returns nil if the ID does not refer to a text layer.
    /// Multiple rects are returned when the range spans multiple lines.
    func textRects(for range: TextRange, in layerID: ID) -> [Rect]? {
        memberData.withLock {
            locked_textRects(&$0, for: range, in: layerID)
        }
    }

    /// Returns the text position after applying the given keyboard navigation action.
    /// Returns nil if the ID does not refer to a text layer.
    func navigateText(_ navigation: TextNavigation, from position: TextPosition, in layerID: ID) -> TextPosition? {
        memberData.withLock {
            locked_navigateText(&$0, navigation, from: position, in: layerID)
        }
    }

    /// Returns the rect where the text insertion caret should be rendered for the given position.
    /// The rect is in the text element's local coordinate space (before element transform).
    /// Returns nil if the ID does not refer to a text layer.
    func caretRect(at position: TextPosition, in layerID: ID) -> Rect? {
        memberData.withLock {
            locked_caretRect(&$0, at: position, in: layerID)
        }
    }

    /// Returns the transform of the layer, or nil if no layer exists with the given ID.
    func layerTransform(for layerID: ID) -> Transform? {
        memberData.withLock {
            $0.objectById[layerID]?.transform
        }
    }

    /// Returns the typographic bounds of a text layer in the element's local
    /// coordinate space (y-down, before element transform). Returns nil if the
    /// ID does not refer to a text layer.
    func typographicBounds(for layerID: ID) -> Rect? {
        memberData.withLock {
            $0.objectById[layerID]?.typographicBounds.map { Rect($0) }
        }
    }
    
    /// Returns an observable proxy that tracks the given layer's
    /// view-space bounds. Multiple callers asking for the same `id`
    /// share the same proxy. The canvas keeps the proxy current as long
    /// as the caller retains it; release the reference (let it
    /// deallocate) to stop tracking.
    ///
    /// If no layer is currently registered for `id`, the proxy is
    /// returned with `viewBounds == nil` and will populate when the
    /// layer appears.
    @MainActor
    func layerProxy(for id: ID) -> CanvasLayerProxy<ID> {
        memberData.withLock { memberData in
            if let existing = memberData.proxies[id]?.value {
                return existing
            }
            let bounds = locked_computeProxyViewBounds(&memberData, for: id)
            let proxy = CanvasLayerProxy<ID>(id: id, viewBounds: bounds)
            memberData.proxies[id] = WeakCanvasLayerProxy(value: proxy)
            return proxy
        }
    }
}

#if os(macOS)
private let useViewTransformForLiveZooming = false
private let areCoordinatesFlippedForWindow = true
#else
private let useViewTransformForLiveZooming = true
private let areCoordinatesFlippedForWindow = false
#endif

private extension CanvasDatabase {
    struct Generated {
        let basedOnLayerID: ID
        let layerIDs: [ID]
    }

    struct Delegate: Sendable {
        var invalidate: @MainActor (Set<CanvasInvalidation>) -> Void = {_ in }
    }
    
    struct MemberData: Sendable {
        /// Top-level layers in z-order (back to front). Group layers
        /// appear here, but their children do not — children are reached
        /// via the group's `children: [ID]` and resolved through
        /// `objectById`.
        var objectsInOrder = [any CanvasObject<ID>]()
        /// Every layer indexed by ID, including children of groups. The
        /// universal lookup map; existing call sites that ask "is there
        /// a layer with this ID?" don't need to know about hierarchy.
        var objectById = [ID: any CanvasObject<ID>]()
        /// Child ID → parent group ID, for fast parent lookup during
        /// delete / reorder / cycle-detection. Top-level layers are not
        /// in this map.
        var parentByChildID = [ID: ID]()
        var generatedLayersByComputedID = [ID: Generated]() // ComputedLayer.id -> generated IDs
        var computedLayersBasedOnID = [ID: [ComputedLayer<ID>]]() // Dependent layer id -> ComputedLayer
        var width: Double
        var height: Double
        var contentTransform: Transform
        var backgroundColor: Color? = nil
        var renderTransparentBackground: Bool = true
        var screenDPI = 72.0
        var bounds: CGRect = .zero
        var isZooming: Bool = false
        var zoomCenter: Point? = nil
        var zoom: CGFloat = 1.0
        var visibleOffset: CGPoint = .zero
        var visibleSize: CGSize = .zero
        var cursor = BaseUIKit.Cursor.default
        var liveZoom: Double = 1.0
        var delegate = Delegate()
        /// Weakly-held layer proxies keyed by ID. Populated by
        /// `layerProxy(for:)` and refreshed on each invalidate dispatch.
        /// Dead entries are swept on refresh.
        var proxies: [ID: WeakCanvasLayerProxy<ID>] = [:]
    }
    
    func setVisibleOffset(_ visibleOffset: CGPoint) {
        let didChange = memberData.withLock {
            let changed = $0.visibleOffset != visibleOffset
            $0.visibleOffset = visibleOffset
            return changed
        }
        // Scroll changes don't go through the invalidate dispatch
        // (the system scroll view handles redraw), but proxies need
        // to track the new viewport.
        if didChange {
            Task { @MainActor in
                self.refreshLayerProxies()
            }
        }
    }
    
    func locked_textIndex(_ memberData: inout MemberData, at point: Point, in layerID: ID) -> TextPosition? {
        guard let canvasText = memberData.objectById[layerID] else {
            return nil
        }
        return canvasText.textIndex(at: point.toCG)
    }

    func locked_textRects(_ memberData: inout MemberData, for range: TextRange, in layerID: ID) -> [Rect]? {
        guard let canvasText = memberData.objectById[layerID] else {
            return nil
        }
        return canvasText.textRects(for: range)?.map { Rect($0) }
    }

    func locked_navigateText(_ memberData: inout MemberData, _ navigation: TextNavigation, from position: TextPosition, in layerID: ID) -> TextPosition? {
        guard let canvasText = memberData.objectById[layerID] else {
            return nil
        }
        return canvasText.navigateText(navigation, from: position)
    }

    func locked_caretRect(_ memberData: inout MemberData, at position: TextPosition, in layerID: ID) -> Rect? {
        guard let canvasText = memberData.objectById[layerID] else {
            return nil
        }
        return canvasText.caretRect(at: position).map { Rect($0) }
    }

    func locked_drawElements(_  memberData: inout MemberData, ids: Set<ID>, in rect: CGRect, into context: CGContext, atScale scale: CGFloat) {
        for object in memberData.objectsInOrder where ids.contains(object.id) {
            object.draw(rect, into: context, atScale: scale, renderingCache: renderingCache)
        }
    }
    
    func locked_toEvent(_ memberData: inout MemberData) -> EventCanvas {
            EventCanvas(
                dimensions: locked_dimensions(&memberData),
                zoom: locked_externalZoom(&memberData),
                scrollPosition: locked_scrollPositionInDocumentCoords(&memberData),
                visibleRect: locked_visibleRectInDocumentCoords(&memberData),
                areWindowCoordsFlipped: areCoordinatesFlippedForWindow
            )
    }
    
    func locked_scrollPositionInDocumentCoords(_ memberData: inout MemberData) -> Point {
        Point(locked_convertViewToDocument(&memberData, memberData.visibleOffset))
    }
    
    func locked_visibleRectInDocumentCoords(_ memberData: inout MemberData) -> Rect {
        Rect(
            locked_convertViewToDocument(
                &memberData,
                CGRect(
                    origin: memberData.visibleOffset,
                    size: memberData.visibleSize
                )
            )
        )
    }
    
    func locked_externalZoom(_ memberData: inout MemberData) -> Double {
        if memberData.isZooming && useViewTransformForLiveZooming {
            memberData.liveZoom
        } else {
            memberData.zoom
        }
    }

    func locked_contentSize(_ memberData: inout MemberData) -> CGSize {
        let contentOffset = locked_contentOffset(&memberData)
        let zoom = memberData.zoom
        return CGSize(
            width: memberData.width * zoom + contentOffset.x * 2.0,
            height: memberData.height * zoom + contentOffset.y * 2.0
        )
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
        let willDrawRects = ids.compactMap { memberData.objectById[$0]?.willDrawRect }
        let union = willDrawRects.reduce(CGRect?.none) { $0?.union($1) ?? $1 }
        return Rect(union ?? .zero)
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
        let intersectInObjectCoords = intersectInDocumentCoords
            .applying(locked_contentAffineTransform(&memberData).inverted())
        for object in memberData.objectsInOrder {
            object.draw(intersectInObjectCoords, into: context, atScale: memberData.zoom, renderingCache: renderingCache)
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
            .applying(locked_contentAffineTransform(&memberData).inverted())
    }

    func locked_convertViewToDocument(_ memberData: inout MemberData, _ rectInViewCoords: CGRect) -> CGRect {
        rectInViewCoords.applying(locked_transform(&memberData).inverted())
            .applying(locked_contentAffineTransform(&memberData).inverted())
    }

    func locked_convertDocumentToView(_ memberData: inout MemberData, _ pointInDocumentCoords: CGPoint) -> CGPoint {
        pointInDocumentCoords.applying(locked_contentAffineTransform(&memberData))
            .applying(locked_transform(&memberData))
    }

    func locked_convertDocumentToView(_ memberData: inout MemberData, _ rectInDocumentCoords: CGRect) -> CGRect {
        rectInDocumentCoords.applying(locked_contentAffineTransform(&memberData))
            .applying(locked_transform(&memberData))
    }

    /// Computes the outer view-space bounds of the layer at `id`, used
    /// by `CanvasLayerProxy`. For a regular layer, this is its
    /// `willDrawRect` (decorations included) projected through the
    /// content + viewport transforms. For a `ComputedLayer`, it's the
    /// union of all generated sub-objects' projected rects. Returns nil
    /// if no layer is currently registered for `id`.
    func locked_computeProxyViewBounds(_ memberData: inout MemberData, for id: ID) -> Rect? {
        let documentRect: CGRect
        if let object = memberData.objectById[id] {
            documentRect = object.willDrawRect
        } else if let generated = memberData.generatedLayersByComputedID[id] {
            var union: CGRect? = nil
            for subID in generated.layerIDs {
                guard let object = memberData.objectById[subID] else { continue }
                let r = object.willDrawRect
                union = union.map { $0.union(r) } ?? r
            }
            guard let resolved = union else { return nil }
            documentRect = resolved
        } else {
            return nil
        }
        let viewRect = locked_convertDocumentToView(&memberData, documentRect)
        return Rect(viewRect)
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
        let scale = memberData.zoom
        // Walk top-level objects topmost-first; the first non-nil hit
        // wins. Groups recurse internally via their own `hitLayer`.
        for object in memberData.objectsInOrder.reversed() {
            if let hit = object.hitLayer(at: cgLocation, atScale: scale, including: predicate) {
                return [hit]
            }
        }
        return []
    }

    func locked_layersIntersectingBounds(_ memberData: inout MemberData, _ bounds: Rect, including predicate: (ID) -> Bool) -> [Layer<ID>] {
        let cgBounds = bounds.toCG
        let scale = memberData.zoom
        return memberData.objectsInOrder.flatMap {
            $0.intersectingLayers(cgBounds, atScale: scale, including: predicate)
        }
    }

    func locked_layersContainingBounds(_ memberData: inout MemberData, _ bounds: Rect, including predicate: (ID) -> Bool) -> [Layer<ID>] {
        let cgBounds = bounds.toCG
        let scale = memberData.zoom
        return memberData.objectsInOrder.flatMap {
            $0.containingLayers(cgBounds, atScale: scale, including: predicate)
        }
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
            
        case .beginZooming:
            memberData.isZooming = true
            memberData.liveZoom = memberData.zoom
            memberData.zoomCenter = locked_visibleCenterPoint(&memberData)
            
        case .endZooming:
            if useViewTransformForLiveZooming {
                // Force a re-render
                locked_zoom(
                    &memberData,
                    to: memberData.liveZoom,
                    centeredAt: memberData.zoomCenter,
                    invalidates: &invalidates
                )
            }
            memberData.isZooming = false
            memberData.zoomCenter = nil
            memberData.liveZoom = memberData.zoom
            if useViewTransformForLiveZooming {
                // Reset the the view transform now that we've scheduled a re-render
                locked_invalidateLiveZoomViewTransform(&memberData, into: &invalidates)
            }
            
        case let .zoomTo(zoom, centeredAt: location):
            if memberData.isZooming && useViewTransformForLiveZooming {
                locked_liveZoom(&memberData, to: zoom, centeredAt: location, invalidates: &invalidates)
            } else {
                locked_zoom(&memberData, to: zoom, centeredAt: location, invalidates: &invalidates)
            }
            
        case let .updateScrollPosition(scrollPosition):
            locked_updateScrollPosition(&memberData, to: scrollPosition, into: &invalidates)
            
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
        
    func locked_liveZoom(
        _ memberData: inout MemberData,
        to zoom: Double,
        centeredAt location: Point?,
        invalidates: inout Set<CanvasInvalidation>
    ) {
        if memberData.liveZoom != zoom {
            memberData.liveZoom = zoom
            locked_invalidateLiveZoomViewTransform(&memberData, into: &invalidates)
        }
    }

    func locked_invalidateLiveZoomViewTransform(_ memberData: inout MemberData, into invalids: inout Set<CanvasInvalidation>) {
        #if os(iOS)
        if memberData.zoom == memberData.liveZoom {
            invalids.insert(.invalidateViewScale(1.0))
        } else {
            let viewScale = memberData.liveZoom / memberData.zoom
            invalids.insert(.invalidateViewScale(viewScale))
        }
        #endif
    }
    
    func locked_zoom(
        _ memberData: inout MemberData,
        to zoom: Double,
        centeredAt location: Point?,
        invalidates: inout Set<CanvasInvalidation>
    ) {
        let newLocation = (location ?? memberData.zoomCenter) ?? locked_visibleCenterPoint(&memberData)
        if memberData.zoom != zoom {
            memberData.zoom = zoom
            locked_invalidateContentSize(&memberData, into: &invalidates)
            locked_updateScrollPositionCenter(&memberData, to: newLocation, into: &invalidates)
        }
    }
        
    func locked_visibleViewRect(_ memberData: inout MemberData) -> CGRect {
        let viewRect = CGRect(origin: memberData.visibleOffset, size: memberData.visibleSize)
        return viewRect
    }
    
    func locked_visibleDocumentRect(_ memberData: inout MemberData) -> Rect {
        let viewRectInDocumentCoords = locked_convertViewToDocument(&memberData, locked_visibleViewRect(&memberData))
        return Rect(viewRectInDocumentCoords)
    }
    
    func locked_visibleCenterPoint(_ memberData: inout MemberData) -> Point {
        var visibleRect = locked_visibleDocumentRect(&memberData)
        if visibleRect.width >= memberData.width {
            visibleRect.origin.x = 0
            visibleRect.size.width = memberData.width
        }
        if visibleRect.height >= memberData.height {
            visibleRect.origin.y = 0
            visibleRect.size.height = memberData.height
        }
        return visibleRect.middle
    }
    
    func locked_updateScrollPosition(_ memberData: inout MemberData, to position: Point, into invalidates: inout Set<CanvasInvalidation>) {
        let viewPosition = position
            .applying(locked_contentAffineTransform(&memberData))
            .applying(locked_transform(&memberData))

        // TODO: we should do some range checking here and rein it in
        invalidates.insert(.scrollPosition(viewPosition.toCG))
    }

    func locked_updateScrollPositionCenter(_ memberData: inout MemberData, to position: Point, into invalidates: inout Set<CanvasInvalidation>) {
        let viewPosition = position
            .applying(locked_contentAffineTransform(&memberData))
            .applying(locked_transform(&memberData))
        invalidates.insert(.scrollPositionCenteredAt(viewPosition.toCG))
    }

    func locked_upsertLayer(
        _ memberData: inout MemberData,
        _ layer: Layer<ID>,
        at index: CanvasIndex<ID>,
        invalidates: inout Set<CanvasInvalidation>
    ) {
        if let existing = memberData.objectById[layer.id] {
            locked_transformLayerInvalidateRect(
                &memberData,
                from: existing.updateLayer(layer),
                into: &invalidates
            )
            // Group's child membership may have changed in the new
            // layer value — re-resolve child refs from the (possibly
            // updated) children IDs.
            if case .group = layer {
                locked_syncGroupChildren(&memberData, groupID: layer.id)
            }
            locked_updateComputedLayers(&memberData, basedOn: layer, invalidates: &invalidates)
        } else if let canvasObject = make(from: layer) {
            locked_insert(&memberData, canvasObject, at: index, invalidates: &invalidates)
        } else if case let .computed(computed) = layer,
                  let basedOn = memberData.objectById[computed.basedOn] {
            let newLayers = computed.factory(
                basedOn.layer,
                withContext: LayerFactoryContext(structurePath: basedOn.structurePath, typographicBounds: basedOn.typographicBounds.map { Rect($0) })
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
            withContext: LayerFactoryContext(structurePath: basedOn.structurePath, typographicBounds: basedOn.typographicBounds.map { Rect($0) })
        )
        
        locked_upsertComputedLayers(&memberData, newLayers, for: computedLayer, at: nil, invalidates: &invalidates)
    }
    
    func locked_upsertComputedLayers(
        _ memberData: inout MemberData,
        _ computedLayers: [Layer<ID>],
        for layer: ComputedLayer<ID>,
        at index: CanvasIndex<ID>?,
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
            withContext: LayerFactoryContext(structurePath: basedObject.structurePath, typographicBounds: basedObject.typographicBounds.map { Rect($0) })
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
    
    func locked_reorderLayer(_ memberData: inout MemberData, fromID: ID, to toIndex: CanvasIndex<ID>, invalidates: inout Set<CanvasInvalidation>) {
        guard let object = memberData.objectById[fromID] else { return }
        locked_invalidateObject(&memberData, object, into: &invalidates)

        let fromParent = memberData.parentByChildID[fromID]
        let toParent = toIndex.parent

        if fromParent == toParent {
            // Same container — just move within its list.
            if let parentID = fromParent {
                guard let parent = memberData.objectById[parentID],
                      case let .group(parentLayer) = parent.layer
                else { return }
                var children = parentLayer.children
                guard let fromPosition = children.firstIndex(of: fromID) else { return }
                let resolvedTo: Int
                switch toIndex.position {
                case .last: resolvedTo = children.count
                case let .at(requestedPosition): resolvedTo = min(max(requestedPosition, 0), children.count)
                }
                children.reorder(from: fromPosition, to: resolvedTo)
                locked_transformLayerInvalidateRect(
                    &memberData,
                    from: parent.updateLayer(.group(parentLayer.replacingChildren(children))),
                    into: &invalidates
                )
                locked_syncGroupChildren(&memberData, groupID: parentID)
            } else if let fromPosition = memberData.objectsInOrder.firstIndex(where: { $0.id == fromID }) {
                memberData.objectsInOrder.reorder(from: fromPosition, to: locked_resolveTopLevel(&memberData, toIndex))
            }
        } else {
            // Re-parent: pop from old container, push into new.
            // Cycle check before we touch state.
            if let newParentID = toParent {
                if newParentID == fromID
                    || locked_isAncestor(&memberData, ancestorID: fromID, ofChild: newParentID)
                {
                    return
                }
            }

            locked_detachFromContainer(&memberData, id: fromID, invalidates: &invalidates)

            // Re-insert using the index (which will route through the
            // parented branch automatically).
            locked_insert(&memberData, object, at: toIndex, invalidates: &invalidates)
        }
    }

    /// Remove `id` from whichever container holds it (top-level or
    /// a parent group's children list) without removing it from
    /// `objectById`. Used by reorder for the re-parent path so the
    /// CanvasObject identity is preserved across the move.
    func locked_detachFromContainer(
        _ memberData: inout MemberData,
        id: ID,
        invalidates: inout Set<CanvasInvalidation>
    ) {
        if let parentID = memberData.parentByChildID[id] {
            if let parent = memberData.objectById[parentID],
               case let .group(parentLayer) = parent.layer
            {
                let newChildren = parentLayer.children.filter { $0 != id }
                locked_transformLayerInvalidateRect(
                    &memberData,
                    from: parent.updateLayer(.group(parentLayer.replacingChildren(newChildren))),
                    into: &invalidates
                )
                locked_syncGroupChildren(&memberData, groupID: parentID)
            }
            memberData.parentByChildID.removeValue(forKey: id)
        } else if let position = memberData.objectsInOrder.firstIndex(where: { $0.id == id }) {
            memberData.objectsInOrder.remove(at: position)
        }
    }
    
    func locked_contentOffset(_ memberData: inout MemberData) -> CGPoint {
        // Center the content if there's excess space
        let x = max(memberData.visibleSize.width - memberData.width, 0.0) / 2.0
        let y = max(memberData.visibleSize.height - memberData.height, 0.0) / 2.0
        return CGPoint(x: x, y: y)
    }
    
    func locked_transform(_ memberData: inout MemberData) -> CGAffineTransform {
        let contentOffset = locked_contentOffset(&memberData)
        let zoom = memberData.zoom
        return CGAffineTransform.identity
            .translatedBy(x: contentOffset.x, y: contentOffset.y)
            .scaledBy(x: zoom, y: zoom)
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
                    .invalidateViewScale,
                    .invalidateCursor,
                    .scrollPosition,
                    .scrollPositionCenteredAt:
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
            .applying(locked_contentAffineTransform(&memberData))
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
        at index: CanvasIndex<ID>,
        invalidates: inout Set<CanvasInvalidation>
    ) {
        if let parentID = index.parent {
            // Parented insert: the new object joins a group's children
            // list rather than the top-level z-order. The parent must
            // already exist (LayoutEngine emits parents before
            // children; a missing parent here is a programmer error so
            // we silently drop).
            guard let parent = memberData.objectById[parentID],
                  case let .group(parentLayer) = parent.layer
            else { return }

            // Cycle detection: the new object's ID cannot equal the
            // parent's ID or appear in the parent's ancestor chain.
            if object.id == parentID
                || locked_isAncestor(&memberData, ancestorID: object.id, ofChild: parentID)
            {
                return
            }

            var newChildren = parentLayer.children
            let resolvedPosition: Int
            switch index.position {
            case .last:
                resolvedPosition = newChildren.count
            case let .at(requestedPosition):
                resolvedPosition = min(max(requestedPosition, 0), newChildren.count)
            }
            newChildren.insert(object.id, at: resolvedPosition)

            memberData.objectById[object.id] = object
            memberData.parentByChildID[object.id] = parentID
            locked_transformLayerInvalidateRect(
                &memberData,
                from: parent.updateLayer(.group(parentLayer.replacingChildren(newChildren))),
                into: &invalidates
            )
            locked_syncGroupChildren(&memberData, groupID: parentID)
            locked_invalidateRect(&memberData, object.willDrawRect, into: &invalidates)
        } else {
            let trueIndex = locked_resolveTopLevel(&memberData, index)
            memberData.objectsInOrder.insert(object, at: trueIndex)
            memberData.objectById[object.id] = object
            // If the inserted object is itself a group, populate its
            // child refs from its declared children IDs (any that exist
            // yet). Subsequent child upserts will keep it in sync.
            if case .group = object.layer {
                locked_syncGroupChildren(&memberData, groupID: object.id)
            }
            locked_invalidateRect(&memberData, object.willDrawRect, into: &invalidates)
        }
    }

    /// Walks `parentByChildID` upward to check whether `ancestorID` is
    /// an ancestor of `childID`. Used to reject cycles when inserting
    /// into a group.
    func locked_isAncestor(_ memberData: inout MemberData, ancestorID: ID, ofChild childID: ID) -> Bool {
        var cursor: ID? = memberData.parentByChildID[childID]
        while let current = cursor {
            if current == ancestorID { return true }
            cursor = memberData.parentByChildID[current]
        }
        return false
    }

    /// Resolve a group's declared `children: [ID]` against `objectById`
    /// and hand the runtime objects to the group via `setChildren`.
    /// Skips any children that don't yet exist in `objectById` — child
    /// upserts that arrive later trigger another sync that fills them
    /// in.
    func locked_syncGroupChildren(_ memberData: inout MemberData, groupID: ID) {
        guard let group = memberData.objectById[groupID],
              case let .group(groupLayer) = group.layer
        else { return }
        let children = groupLayer.children.compactMap { memberData.objectById[$0] }
        group.setChildren(children)
    }

    func locked_resolve(_ memberData: inout MemberData, _ index: CanvasIndex<ID>?, usingExistingObjects existingObjects: [any CanvasObject]) -> Int {
        if let index {
            return locked_resolveTopLevel(&memberData, index)
        } else if let firstObject = existingObjects.first,
                  let firstObjectIndex = memberData.objectsInOrder.firstIndex(where: { $0 === firstObject }) {
            return firstObjectIndex
        } else {
            return locked_resolveTopLevel(&memberData, .last)
        }
    }

    /// Resolve `index` to an integer position in `objectsInOrder`. Only
    /// valid for top-level (`index.parent == nil`) indices; parented
    /// indices resolve against their group's children list at the
    /// call site that knows the parent.
    func locked_resolveTopLevel(_ memberData: inout MemberData, _ index: CanvasIndex<ID>) -> Int {
        index.resolve(for: memberData.objectsInOrder)
    }
    
    func locked_remove(_ memberData: inout MemberData, byID id: ID, invalidates: inout Set<CanvasInvalidation>) {
        locked_removeConcrete(&memberData, byID: id, invalidates: &invalidates)

        // Cascade: remove any computed layers that depended on this layer
        if let dependents = memberData.computedLayersBasedOnID.removeValue(forKey: id) {
            for computed in dependents {
                if let generated = memberData.generatedLayersByComputedID[computed.id] {
                    locked_removeComputed(&memberData, byID: computed.id, generated: generated, invalidates: &invalidates)
                }
            }
        }
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

        locked_invalidateRect(&memberData, object.didDrawRect, into: &invalidates)

        // If this is a group, recursively remove its children first.
        // Order matters: we want children's invalidation rects
        // collected and parentByChildID entries cleared before the
        // parent is dropped from objectById.
        if case let .group(groupLayer) = object.layer {
            for childID in groupLayer.children {
                locked_remove(&memberData, byID: childID, invalidates: &invalidates)
            }
        }

        // Detach from whichever container holds the object (top-level
        // list or parent group's children).
        if let parentID = memberData.parentByChildID[id] {
            if let parent = memberData.objectById[parentID],
               case let .group(parentLayer) = parent.layer
            {
                let newChildren = parentLayer.children.filter { $0 != id }
                locked_transformLayerInvalidateRect(
                    &memberData,
                    from: parent.updateLayer(.group(parentLayer.replacingChildren(newChildren))),
                    into: &invalidates
                )
                locked_syncGroupChildren(&memberData, groupID: parentID)
            }
            memberData.parentByChildID.removeValue(forKey: id)
        } else if let index = memberData.objectsInOrder.firstIndex(where: { $0.id == id }) {
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
        case let .group(groupLayer):
            CanvasGroup(layer: groupLayer)
        }
    }
    
    func invalidateRects(_ rects: [CGRect]) {
        let (invalidates, delegate) = memberData.withLock { memberData in
            var invalidates = Set<CanvasInvalidation>()
            for rect in rects {
                locked_invalidateRect(&memberData, rect, into: &invalidates)
            }
            return (invalidates, memberData.delegate)
        }
        dispatchInvalidations(invalidates, to: delegate)
    }

    /// Fans invalidations out to the view delegate and refreshes any
    /// live layer proxies on the next MainActor turn. All canvas-mutation
    /// paths funnel through here.
    func dispatchInvalidations(_ invalidates: Set<CanvasInvalidation>, to delegate: Delegate) {
        Task { @MainActor in
            self.refreshLayerProxies()
            delegate.invalidate(invalidates)
        }
    }

    /// Walks live proxies, recomputes their `viewBounds` from the
    /// current canvas state, and sweeps deallocated entries. Called from
    /// every invalidate dispatch (layer mutations, viewport size /
    /// content changes) and from the `visibleOffset` setter (scroll).
    @MainActor
    func refreshLayerProxies() {
        // Collect live proxies + their freshly-computed bounds inside
        // the lock; apply the assignments outside so observers can re-
        // enter the database without deadlocking.
        let updates: [(CanvasLayerProxy<ID>, Rect?)] = memberData.withLock { memberData in
            var alive: [ID: WeakCanvasLayerProxy<ID>] = [:]
            var pending: [(CanvasLayerProxy<ID>, Rect?)] = []
            for (id, weak) in memberData.proxies {
                guard let proxy = weak.value else { continue }
                let bounds = locked_computeProxyViewBounds(&memberData, for: id)
                pending.append((proxy, bounds))
                alive[id] = weak
            }
            memberData.proxies = alive
            return pending
        }
        for (proxy, bounds) in updates where proxy.viewBounds != bounds {
            proxy.viewBounds = bounds
        }
    }
}

// MARK: - Test API
//
// Members in this extension are test-only. Each one surfaces exactly
// one piece of internal hierarchy state that the public API
// deliberately doesn't expose. Keep them narrow — add a focused
// accessor per question rather than a broad "leak internals" hook.

extension CanvasDatabase {
    /// Returns the group ID that claims `childID` as a member, or `nil`
    /// if the layer is top-level or unknown. Re-parent, cycle-rejection,
    /// and cascading-delete tests need this signal to assert the
    /// hierarchy invariants the public `layers(_:)` surface doesn't
    /// reveal.
    func test_parentID(of childID: ID) -> ID? {
        memberData.withLock { $0.parentByChildID[childID] }
    }

    /// Returns the stored `Layer` for any ID — including children of
    /// groups, which the public `layers(.all)` query intentionally
    /// hides. Nested-group tests use this to inspect descendant
    /// `GroupLayer.children` lists.
    func test_layer(byID id: ID) -> Layer<ID>? {
        memberData.withLock { $0.objectById[id]?.layer }
    }
}
