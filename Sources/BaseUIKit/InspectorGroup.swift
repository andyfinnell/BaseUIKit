import SwiftUI

public struct InspectorGroup<Content: View>: View {
    private let title: String
    private let content: () -> Content
    @State private var isExpanded = false
    
    public init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }
    
    public var body: some View {
        #if os(macOS)
        DisclosureGroup(
            isExpanded: $isExpanded,
            content: {
                Form {
                    content()
                }
                .formStyle(.grouped)
            }, label: {
                Button(title) {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }
                .buttonStyle(.plain)
                .font(.headline)
            }
        )
        .padding(.leading)
        #else
        DisclosureGroup(title, content: content)
        #endif
    }
}
