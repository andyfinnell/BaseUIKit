import Foundation
import CoreGraphics
import BaseKit

public extension LineJoin {
    var toCG: CGLineJoin {
        switch self {
        case .bevel: return .bevel
        case .miter: return .miter
        case .round: return .round
        }
    }
}
