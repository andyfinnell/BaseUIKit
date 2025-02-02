import BaseKit

#if canImport(CoreGraphics)
import CoreGraphics

public extension Point {
    init(_ point: CGPoint) {
        self.init(x: point.x, y: point.y)
    }
    
    var toCG: CGPoint {
        .init(x: x, y: y)
    }
    
    func applying(_ t: CGAffineTransform) -> Point {
        // result[row, column] = p[row][0]*m[0][column] + p[row][1] * m[1][column] + p[row][2] * m[2][column]
        
        let p = [[x, y, 1.0]]
        let m = [[t.a, t.b, 0.0],
                 [t.c, t.d, 0.0],
                 [t.tx,t.ty,1.0]]
        
        let result = [
            p[0][0] * m[0][0] + p[0][1] * m[1][0] + p[0][2] * m[2][0],
            p[0][0] * m[0][1] + p[0][1] * m[1][1] + p[0][2] * m[2][1],
            p[0][0] * m[0][2] + p[0][1] * m[1][2] + p[0][2] * m[2][2],
        ]
        
        return Point(x: result[0], y: result[1])
    }
}

#endif

