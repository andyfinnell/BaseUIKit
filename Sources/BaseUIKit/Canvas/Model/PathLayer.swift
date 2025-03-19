import BaseKit
import Foundation

public struct PathLayer<ID: Hashable & Sendable>: Hashable, Sendable, Identifiable {
    public let id: ID
    public let transform: Transform
    public let opacity: Double
    public let blendMode: BlendMode
    public let isVisible: Bool
    public let decorations: [Decoration]
    public let bezier: BezierPath
    public let shouldScaleWithZoom: Bool

    public init(
        id: ID,
        transform: Transform = .identity,
        opacity: Double = 1.0,
        blendMode: BlendMode = .normal,
        isVisible: Bool = true,
        decorations: [Decoration] = [],
        bezier: BezierPath,
        shouldScaleWithZoom: Bool = true
    ) {
        self.id = id
        self.transform = transform
        self.opacity = opacity
        self.blendMode = blendMode
        self.isVisible = isVisible
        self.decorations = decorations
        self.bezier = bezier
        self.shouldScaleWithZoom = shouldScaleWithZoom
    }
}
