import Foundation
import BaseKit

public struct ImageLayer<ID: Hashable & Sendable>: Hashable, Sendable, Identifiable {
    public let id: ID
    public let anchorPoint: AnchorPoint
    public let transform: Transform
    public let opacity: Double
    public let blendMode: BlendMode
    public let isVisible: Bool
    public let width: Double
    public let height: Double
    public let imageData: Data

    public init(
        id: ID,
        anchorPoint: AnchorPoint,
        transform: Transform,
        opacity: Double,
        blendMode: BlendMode,
        isVisible: Bool,
        width: Double,
        height: Double,
        imageData: Data
    ) {
        self.id = id
        self.anchorPoint = anchorPoint
        self.transform = transform
        self.opacity = opacity
        self.blendMode = blendMode
        self.isVisible = isVisible
        self.width = width
        self.height = height
        self.imageData = imageData
    }
}
