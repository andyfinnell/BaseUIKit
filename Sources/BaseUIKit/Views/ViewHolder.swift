import SwiftUI

/// Sometimes View types to hold closures/factories to other View types. However
/// if they store them as raw closures, SwiftUI assumes they change every time
/// and will re-evaluate `body`. In practice, they never change.
///
/// This type will say all closures returning the same type are equal. It is
/// up to the user of the type to ensure that's actually true.
struct ViewHolder<Content: View>: Equatable {
    let content: () -> Content
    
    init(_ content: @escaping () -> Content) {
        self.content = content
    }
        
    nonisolated static func ==(lhs: ViewHolder<Content>, rhs: ViewHolder<Content>) -> Bool {
        true
    }
}
