import SwiftUI

public extension View {
    func inspector<Content: View>(
        isPresented: Bool,
        onChange: @escaping (Bool) -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(
            InspectorPresenterModifier(
                isPresented: isPresented,
                onChange: onChange,
                inspectorContent: content
            )
        )
    }
}

public struct InspectorPresenterModifier<InspectorContent: View>: ViewModifier {
    @State private var isVisible = false
    private let isPresented: Bool
    private let onChange: Callback<Bool>
    private let inspectorContent: ViewHolder<InspectorContent>

    public init(
        isPresented: Bool,
        onChange: @escaping (Bool) -> Void,
        inspectorContent: @escaping () -> InspectorContent
    ) {
        self.isPresented = isPresented
        self.onChange = Callback(onChange)
        self.inspectorContent = ViewHolder(inspectorContent)
    }
    
    public func body(content: Content) -> some View {
        content
            .inspector(isPresented: $isVisible, content: inspectorContent.content)
            .onChange(of: isPresented, initial: true) { old, new in
                isVisible = new
            }
            .onChange(of: isVisible) { old, new in
                guard old != new && new != isPresented else {
                    return
                }
                onChange(new)
            }
    }
}
