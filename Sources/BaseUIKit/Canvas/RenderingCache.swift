import CoreGraphics
import CoreImage
import Synchronization
import BaseKit

public final class RenderingCache: Sendable {
    let ciContext = CIContext()
    private let memberData = Mutex(MemberData())

    public init() {}

    func cachedTileImage(for pattern: BaseKit.Pattern) -> CGImage? {
        memberData.withLock { $0.tileImages[pattern] }
    }

    func cacheTileImage(_ image: CGImage, for pattern: BaseKit.Pattern) {
        memberData.withLock { $0.tileImages[pattern] = image }
    }
}

private extension RenderingCache {
    struct MemberData {
        var tileImages: [BaseKit.Pattern: CGImage] = [:]
    }
}
