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
