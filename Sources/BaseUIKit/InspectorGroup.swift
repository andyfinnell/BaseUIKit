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
                content()
                    .controlSize(.mini)
                    .padding()
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
#else
        DisclosureGroup(
            isExpanded: $isExpanded,
            content: {
                content()
                    .controlSize(.mini)
                    .padding()
            }, label: {
                HStack {
                    Button {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    }

                    Text(title)
                    
                    Spacer()
                }
                .padding()
                .background(Color.secondaryBackground)
            }
        )
#endif
    }
}
