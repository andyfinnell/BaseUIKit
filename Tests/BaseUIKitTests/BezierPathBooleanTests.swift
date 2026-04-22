import BaseKit
import Testing

@testable import BaseUIKit

struct BezierPathBooleanTests {
    @Test func componentsSeparatedWithTwoDisjointRectsReturnsTwo() {
        var path = BezierPath(rect: Rect(x: 0, y: 0, width: 10, height: 10))
        path.append(contentsOf: BezierPath(rect: Rect(x: 100, y: 100, width: 10, height: 10)))

        let components = path.componentsSeparated()

        #expect(components.count == 2)
        #expect(!components[0].isEmpty)
        #expect(!components[1].isEmpty)
    }

    @Test func componentsSeparatedWithSingleRectReturnsOne() {
        let path = BezierPath(rect: Rect(x: 0, y: 0, width: 10, height: 10))

        let components = path.componentsSeparated()

        #expect(components.count == 1)
    }

    @Test func componentsSeparatedWithEmptyPathReturnsNone() {
        let path = BezierPath()

        let components = path.componentsSeparated()

        #expect(components.isEmpty)
    }

    @Test func componentsSeparatedWithOverlappingRectsReturnsOne() {
        var path = BezierPath(rect: Rect(x: 0, y: 0, width: 20, height: 20))
        path.append(contentsOf: BezierPath(rect: Rect(x: 10, y: 10, width: 20, height: 20)))

        let components = path.componentsSeparated(using: .winding)

        #expect(components.count == 1)
    }

    @Test func componentsSeparatedAfterRibbonSubtractionReturnsTwo() {
        let target = BezierPath(rect: Rect(x: 0, y: 0, width: 100, height: 100))
        let ribbon = BezierPath(rect: Rect(x: -10, y: 49, width: 120, height: 2))

        let result = target.subtracting(ribbon)
        let components = result.componentsSeparated()

        #expect(components.count == 2)
        #expect(!components[0].isEmpty)
        #expect(!components[1].isEmpty)
    }
}
