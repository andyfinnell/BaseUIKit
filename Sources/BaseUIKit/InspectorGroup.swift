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
                Text(title)
            }
        )
        .disclosureGroupStyle(InspectorDisclosureStyle())
#else
        DisclosureGroup(
            isExpanded: $isExpanded,
            content: {
                content()
                    .controlSize(.mini)
                    .padding()
            }, label: {
                Text(title)
            }
        )
        .disclosureGroupStyle(InspectorDisclosureStyle())
#endif
    }
}

struct InspectorDisclosureStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack {
            Button {
                withAnimation {
                    configuration.isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Image(systemName: configuration.isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.accentColor)
                        .animation(nil, value: configuration.isExpanded)

                    configuration.label
                        .foregroundColor(.accentColor)

                    Spacer()
                }
                .padding()
            }
            .buttonStyle(.plain)
            #if os(macOS)
            .background(Color.background)
            #else
            .background(Color.secondaryBackground)
            #endif
            
            if configuration.isExpanded {
                configuration.content
            }
        }
    }
}
