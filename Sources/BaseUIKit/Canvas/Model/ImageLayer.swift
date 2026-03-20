import Foundation
import BaseKit

public struct ImageLayer<ID: Hashable & Sendable>: Hashable, Sendable, Identifiable {
    public let id: ID
    public let transform: Transform
    public let opacity: Double
    public let blendMode: BlendMode
    public let isVisible: Bool
    public let width: Double
    public let height: Double
    public let imageData: Data?
    public let clipRect: Rect?
    public let filter: FilterLayer?

    public init(
        id: ID,
        transform: Transform,
        opacity: Double,
        blendMode: BlendMode,
        isVisible: Bool,
        width: Double,
        height: Double,
        imageData: Data?,
        clipRect: Rect? = nil,
        filter: FilterLayer? = nil
    ) {
        self.id = id
        self.transform = transform
        self.opacity = opacity
        self.blendMode = blendMode
        self.isVisible = isVisible
        self.width = width
        self.height = height
        self.imageData = imageData
        self.clipRect = clipRect
        self.filter = filter
    }
}
