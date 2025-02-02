import BaseKit
import CoreGraphics

public extension BlendMode {
    var toCG: CGBlendMode {
        switch self {
        case .normal:
            return .normal
        case .multiply:
            return .multiply
        case .screen:
            return .screen
        case .overlay:
            return .overlay
        case .darken:
            return .darken
        case .lighten:
            return .lighten
        case .colorDodge:
            return .colorDodge
        case .colorBurn:
            return .colorBurn
        case .softLight:
            return .softLight
        case .hardLight:
            return .hardLight
        case .difference:
            return .difference
        case .exclusion:
            return .exclusion
        case .hue:
            return .hue
        case .saturation:
            return .saturation
        case .color:
            return .color
        case .luminosity:
            return .luminosity
        case .clear:
            return .clear
        case .copy:
            return .copy
        case .sourceIn:
            return .sourceIn
        case .sourceOut:
            return .sourceOut
        case .sourceAtop:
            return .sourceAtop
        case .destinationOver:
            return .destinationOver
        case .destinationIn:
            return .destinationIn
        case .destinationOut:
            return .destinationOut
        case .destinationAtop:
            return .destinationAtop
        case .xor:
            return .xor
        case .plusDarker:
            return .plusDarker
        case .plusLighter:
            return .plusLighter
        }
    }
}

