import SwiftUI

public struct InspectorContainer<Content: View>: View {
    private let content: () -> Content
    
    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    public var body: some View {
        #if os(macOS)
        ScrollView {
            content()
        }
        #else
        List {
            content()
        }
        #endif
    }
}
