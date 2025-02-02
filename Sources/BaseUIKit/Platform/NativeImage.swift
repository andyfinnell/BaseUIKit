import Foundation

#if canImport(AppKit)
import AppKit
import UniformTypeIdentifiers

typealias NativeImage = NSImage

extension NativeImage {
    func jpegData(compressionQuality: CGFloat) -> Data? {
        let mutableData = NSMutableData()
        
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let imageDestination = CGImageDestinationCreateWithData(mutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        
        CGImageDestinationAddImage(imageDestination,
                                   cgImage,
                                   nil)
        
        let success = CGImageDestinationFinalize(imageDestination)
        guard success else {
            return nil
        }
        
        return mutableData as Data
    }
}

#endif

#if canImport(UIKit)
import UIKit

typealias NativeImage = UIImage
#endif
