import SwiftUI

public struct InspectorContainer<Content: View>: View {
    private let content: ViewHolder<Content>
    
    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = ViewHolder(content)
    }
    
    public var body: some View {
        ScrollView {
            content.content()
        }
    }
}
