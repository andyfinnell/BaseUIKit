import SwiftUI

public struct PopoverButton<Value: Hashable, Content: View, Label: View>: View {
    private var selection: Binding<Value>
    private let content: () -> Content
    private let label: () -> Label
    @State private var isPresenting = false
    
    public init(
        selection: Binding<Value>,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.selection = selection
        self.content = content
        self.label = label
    }
    
    public var body: some View {
        Button {
            isPresenting.toggle()
        } label: {
            label()
            Image(systemName: "chevron.up.chevron.down")            
        }
        .popover(isPresented: $isPresenting, content: {
            Picker("popover", selection: selection) {
                content()
            }
        })
    }
}
