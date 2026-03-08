import XCTest
import BaseKit
@testable import BaseUIKit

@MainActor
final class MockCanvasDelegate: CanvasCoreViewDelegate {
    private(set) var invalidationCalls = [Set<CanvasInvalidation>]()
    var onInvalidate: (() -> Void)?

    func invalidate(_ invalidations: Set<CanvasInvalidation>) {
        invalidationCalls.append(invalidations)
        onInvalidate?()
    }

    var allInvalidatedRects: [CGRect] {
        invalidationCalls.flatMap { call in
            call.compactMap { invalidation in
                if case let .invalidateRect(rect) = invalidation {
                    return rect
                }
                return nil
            }
        }
    }

    func reset() {
        invalidationCalls.removeAll()
    }
}

@MainActor
final class CanvasInvalidationTests: XCTestCase {

    // MARK: - Helpers

    private func makeDatabase(
        width: Double = 400,
        height: Double = 400
    ) -> (CanvasDatabase<String>, MockCanvasDelegate) {
        let canvas = Canvas<String>(
            width: width,
            height: height,
            contentTransform: .identity,
            backgroundColor: nil,
            layers: []
        )
        let db = CanvasDatabase(canvas: canvas)
        // Set bounds before delegate so the setBounds callback uses the no-op
        // delegate. This mimics what the real NSView/UIView does on layout.
        db.setBounds(CGRect(x: 0, y: 0, width: width, height: height))
        db.setVisibleSize(CGSize(width: width, height: height))
        let delegate = MockCanvasDelegate()
        db.setDelegate(delegate)
        return (db, delegate)
    }

    private func makePathLayer(
        id: String,
        rect: Rect
    ) -> PathLayer<String> {
        PathLayer(
            id: id,
            decorations: [.fill(Fill(paint: .solid(.red)))],
            bezier: BezierPath(rect: rect)
        )
    }

    private func performAndWait(
        _ db: CanvasDatabase<String>,
        _ command: CanvasCommand<String>,
        delegate: MockCanvasDelegate
    ) async {
        let exp = expectation(description: "invalidation")
        delegate.onInvalidate = { exp.fulfill() }
        db.perform(command)
        await fulfillment(of: [exp], timeout: 1.0)
        delegate.onInvalidate = nil
    }

    private func makeBitmapContext(
        width: Int = 500,
        height: Int = 500
    ) -> CGContext {
        CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
    }

    // MARK: - Insert

    func testInsertLayerInvalidatesNewBounds() async throws {
        let (db, delegate) = makeDatabase()
        delegate.reset()

        let layer = makePathLayer(id: "rect1", rect: Rect(x: 10, y: 20, width: 50, height: 40))
        let command = CanvasCommand<String>(.upsertLayer(.path(layer), at: .last))
        await performAndWait(db, command, delegate: delegate)

        let rects = delegate.allInvalidatedRects
        XCTAssertFalse(rects.isEmpty, "Insert should produce invalidation rects")

        let expectedArea = CGRect(x: 10, y: 20, width: 50, height: 40)
        XCTAssertTrue(
            rects.contains(where: { $0.intersects(expectedArea) }),
            "Invalidation should cover the new layer's bounds. Got: \(rects)"
        )
    }

    // MARK: - Update after draw

    func testUpdateLayerAfterDrawInvalidatesOldAndNewBounds() async throws {
        let (db, delegate) = makeDatabase()
        delegate.reset()

        // Insert initial layer
        let layer1 = makePathLayer(id: "rect1", rect: Rect(x: 10, y: 10, width: 50, height: 50))
        let insertCmd = CanvasCommand<String>(.upsertLayer(.path(layer1), at: .last))
        await performAndWait(db, insertCmd, delegate: delegate)

        // Draw so didDrawRect gets set
        let context = makeBitmapContext()
        db.drawRect(CGRect(x: 0, y: 0, width: 500, height: 500), into: context)

        delegate.reset()

        // Update to a new position
        let layer2 = makePathLayer(id: "rect1", rect: Rect(x: 200, y: 200, width: 50, height: 50))
        let updateCmd = CanvasCommand<String>(.upsertLayer(.path(layer2), at: .last))
        await performAndWait(db, updateCmd, delegate: delegate)

        let rects = delegate.allInvalidatedRects
        let oldArea = CGRect(x: 10, y: 10, width: 50, height: 50)
        let newArea = CGRect(x: 200, y: 200, width: 50, height: 50)

        XCTAssertTrue(
            rects.contains(where: { $0.intersects(oldArea) }),
            "Update should invalidate the old bounds where element was drawn. Got: \(rects)"
        )
        XCTAssertTrue(
            rects.contains(where: { $0.intersects(newArea) }),
            "Update should invalidate the new bounds where element will draw. Got: \(rects)"
        )
    }

    // MARK: - Update before draw

    func testUpdateLayerBeforeDrawInvalidatesNewBounds() async throws {
        let (db, delegate) = makeDatabase()
        delegate.reset()

        // Insert layer (no draw)
        let layer1 = makePathLayer(id: "rect1", rect: Rect(x: 10, y: 10, width: 50, height: 50))
        let insertCmd = CanvasCommand<String>(.upsertLayer(.path(layer1), at: .last))
        await performAndWait(db, insertCmd, delegate: delegate)
        delegate.reset()

        // Update to new position without drawing first
        let layer2 = makePathLayer(id: "rect1", rect: Rect(x: 200, y: 200, width: 50, height: 50))
        let updateCmd = CanvasCommand<String>(.upsertLayer(.path(layer2), at: .last))
        await performAndWait(db, updateCmd, delegate: delegate)

        let rects = delegate.allInvalidatedRects
        let newArea = CGRect(x: 200, y: 200, width: 50, height: 50)

        XCTAssertTrue(
            rects.contains(where: { $0.intersects(newArea) }),
            "Update should invalidate new bounds even before first draw. Got: \(rects)"
        )
    }

    // MARK: - Delete after draw

    func testDeleteLayerAfterDrawInvalidatesOldBounds() async throws {
        let (db, delegate) = makeDatabase()
        delegate.reset()

        // Insert and draw
        let layer = makePathLayer(id: "rect1", rect: Rect(x: 30, y: 40, width: 60, height: 80))
        let insertCmd = CanvasCommand<String>(.upsertLayer(.path(layer), at: .last))
        await performAndWait(db, insertCmd, delegate: delegate)

        let context = makeBitmapContext()
        db.drawRect(CGRect(x: 0, y: 0, width: 500, height: 500), into: context)
        delegate.reset()

        // Delete
        let deleteCmd = CanvasCommand<String>(.deleteLayer("rect1"))
        await performAndWait(db, deleteCmd, delegate: delegate)

        let rects = delegate.allInvalidatedRects
        let oldArea = CGRect(x: 30, y: 40, width: 60, height: 80)

        XCTAssertTrue(
            rects.contains(where: { $0.intersects(oldArea) }),
            "Delete should invalidate where the layer was drawn. Got: \(rects)"
        )
    }

    // MARK: - Delete before draw

    func testDeleteLayerBeforeDrawInvalidatesDidDrawRect() async throws {
        let (db, delegate) = makeDatabase()
        delegate.reset()

        // Insert without drawing
        let layer = makePathLayer(id: "rect1", rect: Rect(x: 30, y: 40, width: 60, height: 80))
        let insertCmd = CanvasCommand<String>(.upsertLayer(.path(layer), at: .last))
        await performAndWait(db, insertCmd, delegate: delegate)
        delegate.reset()

        // Delete (didDrawRect is still .zero since no draw happened)
        let deleteCmd = CanvasCommand<String>(.deleteLayer("rect1"))
        await performAndWait(db, deleteCmd, delegate: delegate)

        // didDrawRect is .zero, so the invalidated rect is .zero — the layer was
        // never rendered, so there's nothing on screen to erase. This is expected.
        let rects = delegate.allInvalidatedRects
        let actualArea = CGRect(x: 30, y: 40, width: 60, height: 80)
        let hasActualAreaInvalidation = rects.contains(where: { $0.intersects(actualArea) })

        // Document the current behavior: delete before draw only invalidates .zero
        if !hasActualAreaInvalidation {
            // This is the expected behavior — no screen area was drawn, so .zero is fine
            XCTAssertTrue(
                rects.allSatisfy { $0 == .zero || $0.isEmpty },
                "Delete before draw should only invalidate zero/empty rect. Got: \(rects)"
            )
        }
    }

    // MARK: - No-change update

    func testNoChangeUpdateProducesNoInvalidationRects() async throws {
        let (db, delegate) = makeDatabase()
        delegate.reset()

        // Insert and draw
        let layer = makePathLayer(id: "rect1", rect: Rect(x: 10, y: 10, width: 50, height: 50))
        let insertCmd = CanvasCommand<String>(.upsertLayer(.path(layer), at: .last))
        await performAndWait(db, insertCmd, delegate: delegate)

        let context = makeBitmapContext()
        db.drawRect(CGRect(x: 0, y: 0, width: 500, height: 500), into: context)
        delegate.reset()

        // Upsert the same layer again (no changes)
        let sameCmd = CanvasCommand<String>(.upsertLayer(.path(layer), at: .last))
        await performAndWait(db, sameCmd, delegate: delegate)

        let rects = delegate.allInvalidatedRects
        XCTAssertTrue(
            rects.isEmpty,
            "Updating a layer with identical data should produce no invalidation rects. Got: \(rects)"
        )
    }

    // MARK: - Reorder

    func testReorderLayerInvalidatesBothBounds() async throws {
        let (db, delegate) = makeDatabase()
        delegate.reset()

        // Insert two layers and draw
        let layer1 = makePathLayer(id: "rect1", rect: Rect(x: 10, y: 10, width: 50, height: 50))
        let layer2 = makePathLayer(id: "rect2", rect: Rect(x: 100, y: 100, width: 50, height: 50))
        let insert1 = CanvasCommand<String>(.upsertLayer(.path(layer1), at: .last))
        let insert2 = CanvasCommand<String>(.upsertLayer(.path(layer2), at: .last))
        await performAndWait(db, insert1, delegate: delegate)
        await performAndWait(db, insert2, delegate: delegate)

        let context = makeBitmapContext()
        db.drawRect(CGRect(x: 0, y: 0, width: 500, height: 500), into: context)
        delegate.reset()

        // Reorder rect1 to the end
        let reorderCmd = CanvasCommand<String>(.reorderLayer("rect1", to: .last))
        await performAndWait(db, reorderCmd, delegate: delegate)

        let rects = delegate.allInvalidatedRects
        let rect1Area = CGRect(x: 10, y: 10, width: 50, height: 50)

        XCTAssertTrue(
            rects.contains(where: { $0.intersects(rect1Area) }),
            "Reorder should invalidate the reordered layer's bounds. Got: \(rects)"
        )
    }

    // MARK: - Multiple changes in one command

    func testMultipleChangesInSingleCommand() async throws {
        let (db, delegate) = makeDatabase()
        delegate.reset()

        // Insert two layers at once
        let layer1 = makePathLayer(id: "rect1", rect: Rect(x: 10, y: 10, width: 50, height: 50))
        let layer2 = makePathLayer(id: "rect2", rect: Rect(x: 100, y: 100, width: 50, height: 50))
        let command = CanvasCommand<String>(changes: [
            .upsertLayer(.path(layer1), at: .last),
            .upsertLayer(.path(layer2), at: .last),
        ])
        await performAndWait(db, command, delegate: delegate)

        let rects = delegate.allInvalidatedRects
        let area1 = CGRect(x: 10, y: 10, width: 50, height: 50)
        let area2 = CGRect(x: 100, y: 100, width: 50, height: 50)

        XCTAssertTrue(
            rects.contains(where: { $0.intersects(area1) }),
            "Should invalidate first layer's bounds. Got: \(rects)"
        )
        XCTAssertTrue(
            rects.contains(where: { $0.intersects(area2) }),
            "Should invalidate second layer's bounds. Got: \(rects)"
        )
    }

    // MARK: - Content transform helpers

    private func makeDatabaseWithContentTransform(
        _ contentTransform: Transform,
        width: Double = 100,
        height: Double = 100
    ) -> (CanvasDatabase<String>, MockCanvasDelegate) {
        let canvas = Canvas<String>(
            width: width,
            height: height,
            contentTransform: contentTransform,
            backgroundColor: nil,
            layers: []
        )
        let db = CanvasDatabase(canvas: canvas)
        db.setBounds(CGRect(x: 0, y: 0, width: width, height: height))
        db.setVisibleSize(CGSize(width: width, height: height))
        let delegate = MockCanvasDelegate()
        db.setDelegate(delegate)
        return (db, delegate)
    }

    // MARK: - Insert with content transform

    func testInsertWithScaleDownContentTransformInvalidatesCorrectViewRect() async throws {
        // contentTransform = scale(0.5): maps SVG 200x200 → viewport 100x100
        // Object at SVG (100, 100, 50, 50) → view (50, 50, 25, 25)
        let (db, delegate) = makeDatabaseWithContentTransform(Transform(scaleX: 0.5, y: 0.5))
        delegate.reset()

        let layer = makePathLayer(id: "rect1", rect: Rect(x: 100, y: 100, width: 50, height: 50))
        let command = CanvasCommand<String>(.upsertLayer(.path(layer), at: .last))
        await performAndWait(db, command, delegate: delegate)

        let rects = delegate.allInvalidatedRects
        let expectedViewArea = CGRect(x: 50, y: 50, width: 25, height: 25)
        let wrongArea = CGRect(x: 200, y: 200, width: 100, height: 100)

        XCTAssertFalse(rects.isEmpty, "Insert should produce invalidation rects")
        XCTAssertTrue(
            rects.contains(where: { $0.intersects(expectedViewArea) }),
            "Invalidation should cover view-space area \(expectedViewArea). Got: \(rects)"
        )
        XCTAssertFalse(
            rects.contains(where: { $0.intersects(wrongArea) }),
            "Invalidation should NOT be at the inverted-transform location \(wrongArea). Got: \(rects)"
        )
    }

    func testInsertWithScaleUpContentTransformInvalidatesCorrectViewRect() async throws {
        // contentTransform = scale(2): maps SVG 100x100 → viewport 200x200
        // Object at SVG (30, 30, 20, 20) → view (60, 60, 40, 40)
        let (db, delegate) = makeDatabaseWithContentTransform(
            Transform(scaleX: 2, y: 2),
            width: 200,
            height: 200
        )
        delegate.reset()

        let layer = makePathLayer(id: "rect1", rect: Rect(x: 30, y: 30, width: 20, height: 20))
        let command = CanvasCommand<String>(.upsertLayer(.path(layer), at: .last))
        await performAndWait(db, command, delegate: delegate)

        let rects = delegate.allInvalidatedRects
        let expectedViewArea = CGRect(x: 60, y: 60, width: 40, height: 40)
        let wrongArea = CGRect(x: 15, y: 15, width: 10, height: 10)

        XCTAssertFalse(rects.isEmpty, "Insert should produce invalidation rects")
        XCTAssertTrue(
            rects.contains(where: { $0.intersects(expectedViewArea) }),
            "Invalidation should cover view-space area \(expectedViewArea). Got: \(rects)"
        )
        XCTAssertFalse(
            rects.contains(where: { $0.intersects(wrongArea) && !$0.intersects(expectedViewArea) }),
            "Invalidation should NOT be at the inverted-transform location \(wrongArea). Got: \(rects)"
        )
    }

    // MARK: - Update after draw with content transform

    func testUpdateAfterDrawWithContentTransformInvalidatesCorrectViewRects() async throws {
        // contentTransform = scale(0.5): maps SVG 200x200 → viewport 100x100
        // Use object coords within the viewport range so the draw intersection check passes
        let (db, delegate) = makeDatabaseWithContentTransform(Transform(scaleX: 0.5, y: 0.5))
        delegate.reset()

        // Insert at SVG (50, 50, 30, 30) → view (25, 25, 15, 15)
        let layer1 = makePathLayer(id: "rect1", rect: Rect(x: 50, y: 50, width: 30, height: 30))
        let insertCmd = CanvasCommand<String>(.upsertLayer(.path(layer1), at: .last))
        await performAndWait(db, insertCmd, delegate: delegate)

        // Draw so didDrawRect gets set
        let context = makeBitmapContext(width: 100, height: 100)
        db.drawRect(CGRect(x: 0, y: 0, width: 100, height: 100), into: context)
        delegate.reset()

        // Move to SVG (20, 20, 30, 30) → view (10, 10, 15, 15)
        let layer2 = makePathLayer(id: "rect1", rect: Rect(x: 20, y: 20, width: 30, height: 30))
        let updateCmd = CanvasCommand<String>(.upsertLayer(.path(layer2), at: .last))
        await performAndWait(db, updateCmd, delegate: delegate)

        let rects = delegate.allInvalidatedRects
        let oldViewArea = CGRect(x: 25, y: 25, width: 15, height: 15)
        let newViewArea = CGRect(x: 10, y: 10, width: 15, height: 15)

        XCTAssertTrue(
            rects.contains(where: { $0.intersects(oldViewArea) }),
            "Update should invalidate old view-space bounds \(oldViewArea). Got: \(rects)"
        )
        XCTAssertTrue(
            rects.contains(where: { $0.intersects(newViewArea) }),
            "Update should invalidate new view-space bounds \(newViewArea). Got: \(rects)"
        )
    }

    // MARK: - Delete after draw with content transform

    func testDeleteAfterDrawWithContentTransformInvalidatesCorrectViewRect() async throws {
        // contentTransform = scale(0.5): maps SVG 200x200 → viewport 100x100
        // Use object coords within the viewport range so the draw intersection check passes
        let (db, delegate) = makeDatabaseWithContentTransform(Transform(scaleX: 0.5, y: 0.5))
        delegate.reset()

        // Object at SVG (50, 50, 30, 30) → view (25, 25, 15, 15)
        let layer = makePathLayer(id: "rect1", rect: Rect(x: 50, y: 50, width: 30, height: 30))
        let insertCmd = CanvasCommand<String>(.upsertLayer(.path(layer), at: .last))
        await performAndWait(db, insertCmd, delegate: delegate)

        let context = makeBitmapContext(width: 100, height: 100)
        db.drawRect(CGRect(x: 0, y: 0, width: 100, height: 100), into: context)
        delegate.reset()

        let deleteCmd = CanvasCommand<String>(.deleteLayer("rect1"))
        await performAndWait(db, deleteCmd, delegate: delegate)

        let rects = delegate.allInvalidatedRects
        let expectedViewArea = CGRect(x: 25, y: 25, width: 15, height: 15)

        XCTAssertTrue(
            rects.contains(where: { $0.intersects(expectedViewArea) }),
            "Delete should invalidate old view-space bounds \(expectedViewArea). Got: \(rects)"
        )
    }

    // MARK: - Convert view to document with content transform

    func testConvertViewToDocumentPointWithContentTransform() {
        // contentTransform = scale(0.5): maps SVG 200x200 → viewport 100x100
        // View point (50, 50) → document/SVG point (100, 100)
        let (db, _) = makeDatabaseWithContentTransform(Transform(scaleX: 0.5, y: 0.5))

        let documentPoint = db.convertViewToDocument(CGPoint(x: 50, y: 50))

        XCTAssertEqual(documentPoint.x, 100, accuracy: 0.01,
            "View x=50 should map to document x=100 with scale(0.5). Got: \(documentPoint.x)")
        XCTAssertEqual(documentPoint.y, 100, accuracy: 0.01,
            "View y=50 should map to document y=100 with scale(0.5). Got: \(documentPoint.y)")
    }

    func testConvertViewToDocumentPointWithScaleUpContentTransform() {
        // contentTransform = scale(2): maps SVG 100x100 → viewport 200x200
        // View point (60, 60) → document/SVG point (30, 30)
        let (db, _) = makeDatabaseWithContentTransform(
            Transform(scaleX: 2, y: 2),
            width: 200,
            height: 200
        )

        let documentPoint = db.convertViewToDocument(CGPoint(x: 60, y: 60))

        XCTAssertEqual(documentPoint.x, 30, accuracy: 0.01,
            "View x=60 should map to document x=30 with scale(2). Got: \(documentPoint.x)")
        XCTAssertEqual(documentPoint.y, 30, accuracy: 0.01,
            "View y=60 should map to document y=30 with scale(2). Got: \(documentPoint.y)")
    }

    // MARK: - Insert then delete in sequence

    func testInsertThenDeleteInvalidatesCorrectly() async throws {
        let (db, delegate) = makeDatabase()
        delegate.reset()

        let layer = makePathLayer(id: "rect1", rect: Rect(x: 50, y: 50, width: 100, height: 100))

        // Insert
        let insertCmd = CanvasCommand<String>(.upsertLayer(.path(layer), at: .last))
        await performAndWait(db, insertCmd, delegate: delegate)

        let context = makeBitmapContext()
        db.drawRect(CGRect(x: 0, y: 0, width: 500, height: 500), into: context)
        delegate.reset()

        // Delete
        let deleteCmd = CanvasCommand<String>(.deleteLayer("rect1"))
        await performAndWait(db, deleteCmd, delegate: delegate)

        let rects = delegate.allInvalidatedRects
        let drawnArea = CGRect(x: 50, y: 50, width: 100, height: 100)

        XCTAssertTrue(
            rects.contains(where: { $0.intersects(drawnArea) }),
            "After draw and delete, the drawn area should be invalidated. Got: \(rects)"
        )

        // Verify it was actually removed
        let layers = db.layers(.all, including: { _ in true })
        XCTAssertTrue(
            layers.isEmpty,
            "Layer should be removed after delete"
        )
    }
}
