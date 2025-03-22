import BaseKit

public struct CanvasViewDimensions: Hashable, Sendable {
    public let size: Size
    public let screenDPI: Double
    
    public init(size: Size, screenDPI: Double) {
        self.size = size
        self.screenDPI = screenDPI
    }
}

