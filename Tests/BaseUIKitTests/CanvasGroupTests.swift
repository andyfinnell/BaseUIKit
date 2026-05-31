import BaseKit
import CoreGraphics
import XCTest

@testable import BaseUIKit

/// End-to-end tests for the group-layer surface added in task 1085
/// (Phase 1 + Phase 2). Drives the database through its public
/// `perform(_:)` / `layers(_:)` / `effectBounds(_:)` APIs and asserts on
/// the observable result. Where the internal `parentByChildID` index is
/// the only signal (e.g. cycle rejection), tests fall back to
/// `@testable` access to read the database's MemberData snapshot.
@MainActor
final class CanvasGroupTests: XCTestCase {
    // MARK: - Fixtures

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
        let database = CanvasDatabase(canvas: canvas)
        database.setBounds(CGRect(x: 0, y: 0, width: width, height: height))
        database.setVisibleSize(CGSize(width: width, height: height))
        let delegate = MockCanvasDelegate()
        database.setDelegate(delegate)
        return (database, delegate)
    }

    private func makePath(id: String, rect: Rect) -> PathLayer<String> {
        PathLayer(
            id: id,
            decorations: [.fill(Fill(paint: .solid(.red)))],
            bezier: BezierPath(rect: rect)
        )
    }

    private func makeGroup(
        id: String,
        opacity: Double = 1.0,
        isVisible: Bool = true,
        filter: FilterLayer? = nil,
        children: [String] = []
    ) -> GroupLayer<String> {
        GroupLayer(
            id: id,
            opacity: opacity,
            isVisible: isVisible,
            filter: filter,
            children: children
        )
    }

    private func perform(
        _ database: CanvasDatabase<String>,
        _ delegate: MockCanvasDelegate,
        _ changes: CanvasChange<String>...
    ) async {
        let expectation = expectation(description: "invalidation")
        delegate.onInvalidate = { expectation.fulfill() }
        database.perform(CanvasCommand(changes: changes))
        await fulfillment(of: [expectation], timeout: 1.0)
        delegate.onInvalidate = nil
    }

    /// Reads back the GroupLayer struct stored against `groupID` —
    /// works for groups at any nesting depth via the test-only
    /// `test_layer(byID:)` accessor (the public `layers(.all)` surface
    /// intentionally returns only top-level layers).
    private func storedGroup(
        _ database: CanvasDatabase<String>,
        _ groupID: String
    ) -> GroupLayer<String>? {
        if case let .group(group) = database.test_layer(byID: groupID) {
            return group
        }
        return nil
    }

    /// Looks up parent ID via the test-only accessor. The only signal
    /// for "which group claims this child" — public `layers(_:)`
    /// doesn't surface parentage directly.
    private func parent(of childID: String, in database: CanvasDatabase<String>) -> String? {
        database.test_parentID(of: childID)
    }

    // MARK: - Group lifecycle

    func testInsertTopLevelGroup() async {
        let (database, delegate) = makeDatabase()
        let group = makeGroup(id: "group1")
        await perform(database, delegate, .upsertLayer(.group(group), at: .last))

        let topLevel = database.layers(.all, including: { _ in true })
        XCTAssertEqual(topLevel.count, 1)
        if case let .group(stored) = topLevel[0] {
            XCTAssertEqual(stored.id, "group1")
            XCTAssertTrue(stored.children.isEmpty)
        } else {
            XCTFail("Expected a group layer at top level")
        }
    }

    func testInsertChildIntoGroupAddsToParentMembership() async {
        let (database, delegate) = makeDatabase()
        let group = makeGroup(id: "group1")
        let child = makePath(id: "child1", rect: Rect(x: 10, y: 10, width: 20, height: 20))

        await perform(
            database, delegate,
            .upsertLayer(.group(group), at: .last),
            .upsertLayer(.path(child), at: .last(in: "group1"))
        )

        XCTAssertEqual(storedGroup(database, "group1")?.children, ["child1"])
        XCTAssertEqual(parent(of: "child1", in: database), "group1")
        // The child should NOT appear as a top-level layer.
        let topLevelIDs = database.layers(.all, including: { _ in true }).map(\.id)
        XCTAssertEqual(topLevelIDs, ["group1"])
    }

    func testInsertChildAtSpecificPositionInsideGroup() async {
        let (database, delegate) = makeDatabase()
        await perform(database, delegate, .upsertLayer(.group(makeGroup(id: "group1")), at: .last))
        await perform(database, delegate, .upsertLayer(.path(makePath(id: "a", rect: Rect(x: 0, y: 0, width: 10, height: 10))), at: .last(in: "group1")))
        await perform(database, delegate, .upsertLayer(.path(makePath(id: "b", rect: Rect(x: 20, y: 0, width: 10, height: 10))), at: .last(in: "group1")))
        await perform(database, delegate, .upsertLayer(.path(makePath(id: "c", rect: Rect(x: 40, y: 0, width: 10, height: 10))), at: .at(1, in: "group1")))

        XCTAssertEqual(storedGroup(database, "group1")?.children, ["a", "c", "b"])
    }

    func testInsertChildIntoMissingGroupIsDropped() async {
        let (database, delegate) = makeDatabase()
        let child = makePath(id: "child1", rect: Rect(x: 0, y: 0, width: 10, height: 10))
        await perform(database, delegate, .upsertLayer(.path(child), at: .last(in: "nonexistent-group")))

        XCTAssertEqual(database.layers(.all, including: { _ in true }).count, 0)
        XCTAssertNil(parent(of: "child1", in: database))
    }

    func testNestedGroupMembership() async {
        let (database, delegate) = makeDatabase()
        let outer = makeGroup(id: "outer")
        let inner = makeGroup(id: "inner")
        let leaf = makePath(id: "leaf", rect: Rect(x: 5, y: 5, width: 10, height: 10))

        await perform(
            database, delegate,
            .upsertLayer(.group(outer), at: .last),
            .upsertLayer(.group(inner), at: .last(in: "outer")),
            .upsertLayer(.path(leaf), at: .last(in: "inner"))
        )

        XCTAssertEqual(storedGroup(database, "outer")?.children, ["inner"])
        XCTAssertEqual(storedGroup(database, "inner")?.children, ["leaf"])
        XCTAssertEqual(parent(of: "inner", in: database), "outer")
        XCTAssertEqual(parent(of: "leaf", in: database), "inner")
    }

    // MARK: - Reordering

    func testReorderWithinGroup() async {
        let (database, delegate) = makeDatabase()
        await perform(database, delegate, .upsertLayer(.group(makeGroup(id: "group1")), at: .last))
        for label in ["a", "b", "c"] {
            await perform(database, delegate, .upsertLayer(.path(makePath(id: label, rect: Rect(x: 0, y: 0, width: 10, height: 10))), at: .last(in: "group1")))
        }
        XCTAssertEqual(storedGroup(database, "group1")?.children, ["a", "b", "c"])

        await perform(database, delegate, .reorderLayer("a", to: .at(2, in: "group1")))

        XCTAssertEqual(storedGroup(database, "group1")?.children, ["b", "a", "c"])
        XCTAssertEqual(parent(of: "a", in: database), "group1")
    }

    func testReorderTopLevelLayer() async {
        let (database, delegate) = makeDatabase()
        for (index, label) in ["a", "b", "c"].enumerated() {
            await perform(database, delegate, .upsertLayer(.path(makePath(id: label, rect: Rect(x: Double(index * 20), y: 0, width: 10, height: 10))), at: .last))
        }

        await perform(database, delegate, .reorderLayer("c", to: .at(0)))

        let order = database.layers(.all, including: { _ in true }).map(\.id)
        // `.all` returns layers reversed; flip back to z-order.
        XCTAssertEqual(order.reversed(), ["c", "a", "b"])
    }

    // MARK: - Re-parenting

    func testReparentFromTopLevelIntoGroup() async {
        let (database, delegate) = makeDatabase()
        await perform(database, delegate, .upsertLayer(.group(makeGroup(id: "group1")), at: .last))
        await perform(database, delegate, .upsertLayer(.path(makePath(id: "child1", rect: Rect(x: 0, y: 0, width: 10, height: 10))), at: .last))

        XCTAssertNil(parent(of: "child1", in: database))

        await perform(database, delegate, .reorderLayer("child1", to: .last(in: "group1")))

        XCTAssertEqual(parent(of: "child1", in: database), "group1")
        XCTAssertEqual(storedGroup(database, "group1")?.children, ["child1"])

        let topLevelIDs = database.layers(.all, including: { _ in true }).map(\.id)
        XCTAssertEqual(topLevelIDs.sorted(), ["group1"])
    }

    func testReparentFromGroupToTopLevel() async {
        let (database, delegate) = makeDatabase()
        await perform(database, delegate, .upsertLayer(.group(makeGroup(id: "group1")), at: .last))
        await perform(database, delegate, .upsertLayer(.path(makePath(id: "child1", rect: Rect(x: 0, y: 0, width: 10, height: 10))), at: .last(in: "group1")))

        XCTAssertEqual(parent(of: "child1", in: database), "group1")

        await perform(database, delegate, .reorderLayer("child1", to: .last))

        XCTAssertNil(parent(of: "child1", in: database))
        XCTAssertEqual(storedGroup(database, "group1")?.children, [])
        let topLevelIDs = database.layers(.all, including: { _ in true }).map(\.id).sorted()
        XCTAssertEqual(topLevelIDs, ["child1", "group1"])
    }

    func testReparentBetweenGroupsPreservesObjectIdentity() async {
        let (database, delegate) = makeDatabase()
        await perform(
            database, delegate,
            .upsertLayer(.group(makeGroup(id: "groupA")), at: .last),
            .upsertLayer(.group(makeGroup(id: "groupB")), at: .last),
            .upsertLayer(.path(makePath(id: "child", rect: Rect(x: 0, y: 0, width: 10, height: 10))), at: .last(in: "groupA"))
        )

        await perform(database, delegate, .reorderLayer("child", to: .last(in: "groupB")))

        XCTAssertEqual(parent(of: "child", in: database), "groupB")
        XCTAssertEqual(storedGroup(database, "groupA")?.children, [])
        XCTAssertEqual(storedGroup(database, "groupB")?.children, ["child"])
    }

    // MARK: - Cycle detection

    func testInsertingGroupAsItsOwnChildIsRejected() async {
        let (database, delegate) = makeDatabase()
        let group = makeGroup(id: "group1")
        await perform(database, delegate, .upsertLayer(.group(group), at: .last))

        // Attempting to re-parent the group into itself should be a no-op.
        // We invoke perform without awaiting an invalidate (none expected
        // when the operation is dropped), so just call perform directly.
        database.perform(CanvasCommand(.reorderLayer("group1", to: .last(in: "group1"))))
        // Allow the dispatched delegate task to run.
        try? await Task.sleep(nanoseconds: 50_000_000)

        // Group should still be top-level and have no children.
        XCTAssertNil(parent(of: "group1", in: database))
        XCTAssertEqual(storedGroup(database, "group1")?.children, [])
    }

    func testInsertingAncestorIntoDescendantIsRejected() async {
        let (database, delegate) = makeDatabase()
        await perform(
            database, delegate,
            .upsertLayer(.group(makeGroup(id: "outer")), at: .last),
            .upsertLayer(.group(makeGroup(id: "inner")), at: .last(in: "outer"))
        )

        // Trying to move `outer` inside `inner` would create a cycle.
        database.perform(CanvasCommand(.reorderLayer("outer", to: .last(in: "inner"))))
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertNil(parent(of: "outer", in: database))
        XCTAssertEqual(parent(of: "inner", in: database), "outer")
        XCTAssertEqual(storedGroup(database, "inner")?.children, [])
    }

    // MARK: - Deletion

    func testDeleteChildRemovesFromGroupMembership() async {
        let (database, delegate) = makeDatabase()
        await perform(
            database, delegate,
            .upsertLayer(.group(makeGroup(id: "group1")), at: .last),
            .upsertLayer(.path(makePath(id: "a", rect: Rect(x: 0, y: 0, width: 10, height: 10))), at: .last(in: "group1")),
            .upsertLayer(.path(makePath(id: "b", rect: Rect(x: 20, y: 0, width: 10, height: 10))), at: .last(in: "group1"))
        )

        await perform(database, delegate, .deleteLayer("a"))

        XCTAssertEqual(storedGroup(database, "group1")?.children, ["b"])
        XCTAssertNil(parent(of: "a", in: database))
    }

    func testDeleteGroupCascadesToDescendants() async {
        let (database, delegate) = makeDatabase()
        await perform(
            database, delegate,
            .upsertLayer(.group(makeGroup(id: "outer")), at: .last),
            .upsertLayer(.group(makeGroup(id: "inner")), at: .last(in: "outer")),
            .upsertLayer(.path(makePath(id: "leaf", rect: Rect(x: 0, y: 0, width: 10, height: 10))), at: .last(in: "inner"))
        )

        await perform(database, delegate, .deleteLayer("outer"))

        XCTAssertEqual(database.layers(.all, including: { _ in true }).count, 0)
        XCTAssertNil(parent(of: "inner", in: database))
        XCTAssertNil(parent(of: "leaf", in: database))
        // No layer should answer hit-tests at any of the leaf's prior
        // pixels either.
        let stillHits = database.layers(.underLocation(Point(x: 5, y: 5)), including: { _ in true })
        XCTAssertTrue(stillHits.isEmpty)
    }

    // MARK: - Hit testing

    func testHitInsideChildOfGroupReportsChild() async {
        let (database, delegate) = makeDatabase()
        await perform(
            database, delegate,
            .upsertLayer(.group(makeGroup(id: "group1")), at: .last),
            .upsertLayer(.path(makePath(id: "child1", rect: Rect(x: 10, y: 10, width: 50, height: 50))), at: .last(in: "group1"))
        )

        let result = database.layers(.underLocation(Point(x: 25, y: 25)), including: { _ in true })

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, "child1")
    }

    func testHitOutsideAllChildrenReturnsEmpty() async {
        let (database, delegate) = makeDatabase()
        await perform(
            database, delegate,
            .upsertLayer(.group(makeGroup(id: "group1")), at: .last),
            .upsertLayer(.path(makePath(id: "child1", rect: Rect(x: 10, y: 10, width: 20, height: 20))), at: .last(in: "group1"))
        )

        let result = database.layers(.underLocation(Point(x: 100, y: 100)), including: { _ in true })
        XCTAssertEqual(result.count, 0)
    }

    func testHitWithPredicateFilteringChildReturnsEmpty() async {
        let (database, delegate) = makeDatabase()
        await perform(
            database, delegate,
            .upsertLayer(.group(makeGroup(id: "group1")), at: .last),
            .upsertLayer(.path(makePath(id: "child1", rect: Rect(x: 10, y: 10, width: 50, height: 50))), at: .last(in: "group1"))
        )

        // Predicate rejects the child; group still allows recursion but
        // the leaf no longer matches, so nothing should hit.
        let result = database.layers(.underLocation(Point(x: 25, y: 25)), including: { $0 != "child1" })
        XCTAssertEqual(result.count, 0)
    }

    func testHitInNestedGroupRecurses() async {
        let (database, delegate) = makeDatabase()
        await perform(
            database, delegate,
            .upsertLayer(.group(makeGroup(id: "outer")), at: .last),
            .upsertLayer(.group(makeGroup(id: "inner")), at: .last(in: "outer")),
            .upsertLayer(.path(makePath(id: "leaf", rect: Rect(x: 30, y: 30, width: 40, height: 40))), at: .last(in: "inner"))
        )

        let result = database.layers(.underLocation(Point(x: 50, y: 50)), including: { _ in true })
        XCTAssertEqual(result.first?.id, "leaf")
    }

    func testInvisibleGroupHidesChildrenFromHitTest() async {
        let (database, delegate) = makeDatabase()
        await perform(
            database, delegate,
            .upsertLayer(.group(makeGroup(id: "group1", isVisible: false)), at: .last),
            .upsertLayer(.path(makePath(id: "child1", rect: Rect(x: 10, y: 10, width: 50, height: 50))), at: .last(in: "group1"))
        )

        let result = database.layers(.underLocation(Point(x: 25, y: 25)), including: { _ in true })
        XCTAssertEqual(result.count, 0)
    }

    func testHitTopmostChildWins() async {
        let (database, delegate) = makeDatabase()
        await perform(
            database, delegate,
            .upsertLayer(.group(makeGroup(id: "group1")), at: .last),
            .upsertLayer(.path(makePath(id: "bottom", rect: Rect(x: 0, y: 0, width: 100, height: 100))), at: .last(in: "group1")),
            .upsertLayer(.path(makePath(id: "top", rect: Rect(x: 30, y: 30, width: 40, height: 40))), at: .last(in: "group1"))
        )

        let result = database.layers(.underLocation(Point(x: 50, y: 50)), including: { _ in true })
        XCTAssertEqual(result.first?.id, "top")
    }

    // MARK: - Bounds queries

    func testIntersectingBoundsCollectsGroupChildren() async {
        let (database, delegate) = makeDatabase()
        await perform(
            database, delegate,
            .upsertLayer(.group(makeGroup(id: "group1")), at: .last),
            .upsertLayer(.path(makePath(id: "a", rect: Rect(x: 0, y: 0, width: 30, height: 30))), at: .last(in: "group1")),
            .upsertLayer(.path(makePath(id: "b", rect: Rect(x: 100, y: 100, width: 30, height: 30))), at: .last(in: "group1"))
        )

        let result = database.layers(.intersectingBounds(Rect(x: 10, y: 10, width: 10, height: 10)), including: { _ in true })
        XCTAssertEqual(result.map(\.id), ["a"])
    }

    func testContainingBoundsCollectsGroupChildren() async {
        let (database, delegate) = makeDatabase()
        await perform(
            database, delegate,
            .upsertLayer(.group(makeGroup(id: "group1")), at: .last),
            .upsertLayer(.path(makePath(id: "small", rect: Rect(x: 10, y: 10, width: 10, height: 10))), at: .last(in: "group1")),
            .upsertLayer(.path(makePath(id: "large", rect: Rect(x: 0, y: 0, width: 200, height: 200))), at: .last(in: "group1"))
        )

        let result = database.layers(.containingBounds(Rect(x: 0, y: 0, width: 50, height: 50)), including: { _ in true })
        XCTAssertEqual(result.map(\.id), ["small"])
    }

    // MARK: - effectBounds

    func testEffectBoundsOfGroupReturnsUnionOfChildren() async {
        let (database, delegate) = makeDatabase()
        await perform(
            database, delegate,
            .upsertLayer(.group(makeGroup(id: "group1")), at: .last),
            .upsertLayer(.path(makePath(id: "a", rect: Rect(x: 10, y: 10, width: 20, height: 20))), at: .last(in: "group1")),
            .upsertLayer(.path(makePath(id: "b", rect: Rect(x: 60, y: 60, width: 20, height: 20))), at: .last(in: "group1"))
        )

        let bounds = database.effectBounds(ofIDs: ["group1"])
        // Union of (10,10,20,20) and (60,60,20,20) is (10,10,70,70).
        XCTAssertEqual(bounds.minX, 10)
        XCTAssertEqual(bounds.minY, 10)
        XCTAssertEqual(bounds.maxX, 80)
        XCTAssertEqual(bounds.maxY, 80)
    }

    func testEffectBoundsOfGroupIncludesFilterRegion() async {
        let (database, delegate) = makeDatabase()
        let filter = FilterLayer(region: Rect(x: 0, y: 0, width: 300, height: 300), primitives: [])
        await perform(
            database, delegate,
            .upsertLayer(.group(makeGroup(id: "group1", filter: filter)), at: .last),
            .upsertLayer(.path(makePath(id: "a", rect: Rect(x: 50, y: 50, width: 20, height: 20))), at: .last(in: "group1"))
        )

        let bounds = database.effectBounds(ofIDs: ["group1"])
        // Filter region dominates — expected (0,0,300,300).
        XCTAssertEqual(bounds.minX, 0)
        XCTAssertEqual(bounds.minY, 0)
        XCTAssertEqual(bounds.maxX, 300)
        XCTAssertEqual(bounds.maxY, 300)
    }

    func testEmptyGroupEffectBoundsIsZero() async {
        let (database, delegate) = makeDatabase()
        await perform(database, delegate, .upsertLayer(.group(makeGroup(id: "group1")), at: .last))

        let bounds = database.effectBounds(ofIDs: ["group1"])
        XCTAssertEqual(bounds, Rect(.zero))
    }

    // MARK: - structurePath aggregation

    func testGroupStructurePathIsUnionOfChildren() async {
        let (database, delegate) = makeDatabase()
        await perform(
            database, delegate,
            .upsertLayer(.group(makeGroup(id: "group1")), at: .last),
            .upsertLayer(.path(makePath(id: "a", rect: Rect(x: 10, y: 10, width: 20, height: 20))), at: .last(in: "group1")),
            .upsertLayer(.path(makePath(id: "b", rect: Rect(x: 100, y: 100, width: 20, height: 20))), at: .last(in: "group1"))
        )

        let paths = database.structurePaths(byIDs: ["group1"])
        XCTAssertEqual(paths.count, 1)
        let pathBounds = paths[0].cgPath.boundingBox
        XCTAssertEqual(pathBounds.minX, 10)
        XCTAssertEqual(pathBounds.minY, 10)
        XCTAssertEqual(pathBounds.maxX, 120)
        XCTAssertEqual(pathBounds.maxY, 120)
    }

    // MARK: - Drawing

    private func makeBitmapContext(width: Int = 200, height: Int = 200) -> CGContext {
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

    private func pixel(at point: CGPoint, in image: CGImage) -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8)? {
        guard let provider = image.dataProvider,
              let data = provider.data,
              let bytes = CFDataGetBytePtr(data)
        else { return nil }
        let bytesPerRow = image.bytesPerRow
        let bytesPerPixel = image.bitsPerPixel / 8
        let row = Int(point.y)
        let column = Int(point.x)
        let offset = row * bytesPerRow + column * bytesPerPixel
        return (bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3])
    }

    func testDrawRecursesIntoGroupChildren() async {
        let (database, delegate) = makeDatabase(width: 200, height: 200)
        // Suppress the default checkerboard "transparent background"
        // indicator — pixel assertions want the actual surface alpha,
        // not the checker.
        database.setRenderTransparentBackgroundIndicator(false)
        await perform(
            database, delegate,
            .upsertLayer(.group(makeGroup(id: "group1")), at: .last),
            .upsertLayer(.path(makePath(id: "child1", rect: Rect(x: 50, y: 50, width: 100, height: 100))), at: .last(in: "group1"))
        )

        let context = makeBitmapContext()
        // The canvas pipeline assumes the destination is flipped to
        // top-left origin (matches NSView's `isFlipped == true` path).
        context.translateBy(x: 0, y: 200)
        context.scaleBy(x: 1, y: -1)
        database.drawRect(CGRect(x: 0, y: 0, width: 200, height: 200), into: context)

        let image = context.makeImage()!
        // Pixel inside the child (red fill).
        let inside = pixel(at: CGPoint(x: 100, y: 100), in: image)
        XCTAssertEqual(inside?.red, 255)
        XCTAssertEqual(inside?.green, 0)
        XCTAssertEqual(inside?.blue, 0)
        // Pixel outside the child — background was cleared, so alpha is 0.
        let outside = pixel(at: CGPoint(x: 10, y: 10), in: image)
        XCTAssertEqual(outside?.alpha, 0)
    }

    func testGroupOpacityAppliesAcrossChildrenAsAUnit() async {
        let (database, delegate) = makeDatabase(width: 200, height: 200)
        database.setRenderTransparentBackgroundIndicator(false)
        // Two overlapping opaque red rects inside a group at 0.5
        // opacity. If opacity were applied per-child, the overlap would
        // composite as red over red and then attenuate — the overlap's
        // post-blend alpha differs from the non-overlap's. With group
        // opacity, the children render to a fresh offscreen at full
        // alpha first, so the overlap matches the non-overlap, and
        // both composite back at 0.5.
        await perform(
            database, delegate,
            .upsertLayer(.group(makeGroup(id: "group1", opacity: 0.5)), at: .last),
            .upsertLayer(.path(makePath(id: "a", rect: Rect(x: 50, y: 50, width: 100, height: 100))), at: .last(in: "group1")),
            .upsertLayer(.path(makePath(id: "b", rect: Rect(x: 75, y: 75, width: 100, height: 100))), at: .last(in: "group1"))
        )

        let context = makeBitmapContext()
        context.translateBy(x: 0, y: 200)
        context.scaleBy(x: 1, y: -1)
        database.drawRect(CGRect(x: 0, y: 0, width: 200, height: 200), into: context)
        let image = context.makeImage()!

        let nonOverlap = pixel(at: CGPoint(x: 60, y: 60), in: image)!
        let overlap = pixel(at: CGPoint(x: 100, y: 100), in: image)!
        XCTAssertEqual(nonOverlap.alpha, overlap.alpha,
            "Group opacity must produce uniform alpha; per-child opacity would differ in the overlap.")
        // 0.5 over transparent → ~127 alpha (with rounding tolerance).
        XCTAssertEqual(Int(overlap.alpha), 127, accuracy: 2,
            "Group opacity 0.5 should produce ~127 alpha over a cleared background.")
    }

    // MARK: - updateLayer

    func testReemittingGroupWithDifferentChildOrderSyncsChildRefs() async {
        let (database, delegate) = makeDatabase()
        await perform(
            database, delegate,
            .upsertLayer(.group(makeGroup(id: "group1")), at: .last),
            .upsertLayer(.path(makePath(id: "a", rect: Rect(x: 0, y: 0, width: 10, height: 10))), at: .last(in: "group1")),
            .upsertLayer(.path(makePath(id: "b", rect: Rect(x: 20, y: 0, width: 10, height: 10))), at: .last(in: "group1"))
        )

        // Re-emit the group with children reversed. Because both `a`
        // and `b` already exist in objectById, the database takes the
        // updateLayer branch and must re-sync the group's child refs.
        await perform(
            database, delegate,
            .upsertLayer(.group(makeGroup(id: "group1", children: ["b", "a"])), at: .last)
        )

        XCTAssertEqual(storedGroup(database, "group1")?.children, ["b", "a"])
        // Hit-test of the topmost-z child should now be `a` (was `b`).
        let result = database.layers(.underLocation(Point(x: 5, y: 5)), including: { _ in true })
        XCTAssertEqual(result.first?.id, "a")
    }

    func testReemittingGroupWithNewEffectsInvalidatesOldBounds() async {
        let (database, delegate) = makeDatabase()
        await perform(
            database, delegate,
            .upsertLayer(.group(makeGroup(id: "group1")), at: .last),
            .upsertLayer(.path(makePath(id: "a", rect: Rect(x: 10, y: 10, width: 20, height: 20))), at: .last(in: "group1"))
        )

        // Draw so the group has a non-zero lastDrawnBounds.
        let context = makeBitmapContext()
        context.translateBy(x: 0, y: 200)
        context.scaleBy(x: 1, y: -1)
        database.drawRect(CGRect(x: 0, y: 0, width: 200, height: 200), into: context)

        delegate.reset()

        let withOpacity = makeGroup(id: "group1", opacity: 0.5, children: ["a"])
        await perform(database, delegate, .upsertLayer(.group(withOpacity), at: .last))

        XCTAssertFalse(delegate.allInvalidatedRects.isEmpty,
            "Updating the group's opacity must invalidate the canvas area where it was drawn.")
    }
}
