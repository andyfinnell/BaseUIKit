import BaseKit
import Foundation

public struct PathLayer<ID: Hashable & Sendable>: Hashable, Sendable, Identifiable {
    public let id: ID
    public let anchorPoint: AnchorPoint
    public let transform: Transform
    public let opacity: Double
    public let blendMode: BlendMode
    public let isVisible: Bool
    public let decorations: [Decoration]
    public let bezier: BezierPath

    public init(
        id: ID,
        anchorPoint: AnchorPoint = .topLeft,
        transform: Transform = .identity,
        opacity: Double = 1.0,
        blendMode: BlendMode = .normal,
        isVisible: Bool = true,
        decorations: [Decoration] = [],
        bezier: BezierPath
    ) {
        self.id = id
        self.anchorPoint = anchorPoint
        self.transform = transform
        self.opacity = opacity
        self.blendMode = blendMode
        self.isVisible = isVisible
        self.decorations = decorations
        self.bezier = bezier
    }
}
