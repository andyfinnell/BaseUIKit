import BaseKit
import SwiftUI

public extension BaseKit.Angle {
    init(_ angle: SwiftUI.Angle) {
        self.init(radians: angle.radians)
    }
    
    var toSwiftUI: SwiftUI.Angle {
        SwiftUI.Angle(radians: radians)
    }
}
