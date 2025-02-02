import Foundation
import CoreGraphics
import BaseKit

public extension LineCap {
    var toCG: CGLineCap {
        switch self {
        case .butt: return .butt
        case .round: return .round
        case .square: return .square
        }
    }
}
