import BaseKit
import CoreGraphics
import Testing

@testable import BaseUIKit

@MainActor
struct CanvasLayerProxyTests {
    // MARK: - Basic vending

    @Test func proxyForExistingLayerReturnsImmediateBounds() async throws {
        let (db, delegate) = makeDatabase()

        let layer = makePathLayer(id: "rect1", rect: Rect(x: 10, y: 20, width: 50, height: 40))
        await performAndWait(
            db, CanvasCommand<String>(.upsertLayer(.path(layer), at: .last)), delegate: delegate)

        let proxy = db.layerProxy(for: "rect1")
        let bounds = try #require(proxy.viewBounds)
        // PathLayer with no stroke decoration has willDrawRect == bezier bounds.
        #expect(abs(bounds.minX - 10) < 0.5)
        #expect(abs(bounds.minY - 20) < 0.5)
        #expect(abs(bounds.width - 50) < 0.5)
        #expect(abs(bounds.height - 40) < 0.5)
    }

    @Test func proxyForUnknownLayerReturnsNilBounds() {
        let (db, _) = makeDatabase()
        let proxy = db.layerProxy(for: "missing")
        #expect(proxy.viewBounds == nil)
    }

    @Test func sameIDReturnsSameProxyInstance() {
        let (db, _) = makeDatabase()
        let p1 = db.layerProxy(for: "rect1")
        let p2 = db.layerProxy(for: "rect1")
        #expect(p1 === p2)
    }

    @Test func differentIDsReturnDistinctProxies() {
        let (db, _) = makeDatabase()
        let a = db.layerProxy(for: "a")
        let b = db.layerProxy(for: "b")
        #expect(a !== b)
    }

    // MARK: - Live updates

    @Test func proxyPopulatesWhenLayerAppearsLater() async throws {
        let (db, delegate) = makeDatabase()
        let proxy = db.layerProxy(for: "rect1")
        #expect(proxy.viewBounds == nil)

        let layer = makePathLayer(id: "rect1", rect: Rect(x: 10, y: 20, width: 50, height: 40))
        await performAndWait(
            db, CanvasCommand<String>(.upsertLayer(.path(layer), at: .last)), delegate: delegate)

        let bounds = try #require(proxy.viewBounds)
        #expect(abs(bounds.minX - 10) < 0.5)
    }

    @Test func proxyClearsWhenLayerIsDeleted() async throws {
        let (db, delegate) = makeDatabase()
        let layer = makePathLayer(id: "rect1", rect: Rect(x: 10, y: 20, width: 50, height: 40))
        await performAndWait(
            db, CanvasCommand<String>(.upsertLayer(.path(layer), at: .last)), delegate: delegate)

        let proxy = db.layerProxy(for: "rect1")
        #expect(proxy.viewBounds != nil)

        await performAndWait(
            db, CanvasCommand<String>(.deleteLayer("rect1")), delegate: delegate)

        #expect(proxy.viewBounds == nil)
    }

    @Test func proxyTracksLayerMovement() async throws {
        let (db, delegate) = makeDatabase()
        let layer1 = makePathLayer(id: "rect1", rect: Rect(x: 10, y: 20, width: 50, height: 40))
        await performAndWait(
            db, CanvasCommand<String>(.upsertLayer(.path(layer1), at: .last)), delegate: delegate)

        let proxy = db.layerProxy(for: "rect1")
        let initialBounds = try #require(proxy.viewBounds)
        #expect(abs(initialBounds.minX - 10) < 0.5)

        let layer2 = makePathLayer(id: "rect1", rect: Rect(x: 100, y: 100, width: 50, height: 40))
        await performAndWait(
            db, CanvasCommand<String>(.upsertLayer(.path(layer2), at: .last)), delegate: delegate)

        let movedBounds = try #require(proxy.viewBounds)
        #expect(abs(movedBounds.minX - 100) < 0.5)
    }

    // MARK: - Viewport tracking

    @Test func proxyReprojectsWhenContentTransformScales() async throws {
        // contentTransform = scale(0.5): object at (100, 100, 50, 50) → view (50, 50, 25, 25)
        let (db, delegate) = makeDatabase(contentTransform: Transform(scaleX: 0.5, y: 0.5))
        let layer = makePathLayer(id: "rect1", rect: Rect(x: 100, y: 100, width: 50, height: 50))
        await performAndWait(
            db, CanvasCommand<String>(.upsertLayer(.path(layer), at: .last)), delegate: delegate)

        let proxy = db.layerProxy(for: "rect1")
        let bounds = try #require(proxy.viewBounds)
        #expect(abs(bounds.minX - 50) < 0.5)
        #expect(abs(bounds.minY - 50) < 0.5)
        #expect(abs(bounds.width - 25) < 0.5)
        #expect(abs(bounds.height - 25) < 0.5)
    }

    // MARK: - Lifecycle (weak retention)

    @Test func proxyDeallocatesWhenCallerReleases() async throws {
        let (db, delegate) = makeDatabase()
        let layer = makePathLayer(id: "rect1", rect: Rect(x: 10, y: 20, width: 50, height: 40))
        await performAndWait(
            db, CanvasCommand<String>(.upsertLayer(.path(layer), at: .last)), delegate: delegate)

        weak var weakProxy: CanvasLayerProxy<String>?
        do {
            let strong = db.layerProxy(for: "rect1")
            weakProxy = strong
            #expect(weakProxy != nil)
        }
        // Force a refresh sweep so the dead-entry cleanup runs.
        let layer2 = makePathLayer(id: "rect2", rect: Rect(x: 0, y: 0, width: 1, height: 1))
        await performAndWait(
            db, CanvasCommand<String>(.upsertLayer(.path(layer2), at: .last)), delegate: delegate)

        #expect(weakProxy == nil, "Proxy should be released once the caller drops their reference")
    }
}

// MARK: - Helpers

private extension CanvasLayerProxyTests {
    func makeDatabase(
        width: Double = 400,
        height: Double = 400,
        contentTransform: Transform = .identity
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

    func makePathLayer(id: String, rect: Rect) -> PathLayer<String> {
        PathLayer(
            id: id,
            decorations: [.fill(Fill(paint: .solid(.red)))],
            bezier: BezierPath(rect: rect)
        )
    }

    /// Perform a canvas command and wait for the resulting invalidation
    /// to land. Replaces XCTest's `expectation` / `fulfillment` pattern
    /// with a continuation so the helper stays Swift-Testing-native.
    func performAndWait(
        _ db: CanvasDatabase<String>,
        _ command: CanvasCommand<String>,
        delegate: MockCanvasDelegate
    ) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            delegate.onInvalidate = {
                delegate.onInvalidate = nil
                continuation.resume()
            }
            db.perform(command)
        }
    }
}
