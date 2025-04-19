import SwiftUI

#if os(iOS)

public struct MenuBar<Content: View>: View {
    private let content: ViewHolder<Content>
    
    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = ViewHolder(content)
    }
    
    public var body: some View {
        HStack {
            Menu {
                content.content()
            } label: {
                Label("Menu", systemImage: "filemenu.and.selection")
            }
        }
    }
}

#Preview {
    VStack {
        HStack {
            MenuBar {
                Menu("Zoom") {
                    Button("Zoom in", action: { })
                    Button("Zoom out", action: { })
                }
                
                Menu("Canvas") {
                    Button("Resize...", action: { })
                }
            }
            Spacer()
        }
        Spacer()
    }.padding()
}

#else

public struct MenuBar<Content: View>: View {
    public init(@ViewBuilder content: @escaping () -> Content) {
    }
    
    public var body: some View {
        EmptyView()
    }
}

#endif
