import SwiftUI

public extension View {
    func sheet<T: Equatable, Content: View>(
        isPresented: T?,
        onChange: @escaping (T?) -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(
            SheetPresenterModifier(
                isPresented: isPresented,
                onChange: onChange,
                sheetContent: content
            )
        )
    }
}

public struct SheetPresenterModifier<T: Equatable, SheetContent: View>: ViewModifier {
    @State private var isVisible = false
    private let isPresented: T?
    private let onChange: (T?) -> Void
    private let sheetContent: () -> SheetContent

    public init(
        isPresented: T?,
        onChange: @escaping (T?) -> Void,
        sheetContent: @escaping () -> SheetContent
    ) {
        self.isPresented = isPresented
        self.onChange = onChange
        self.sheetContent = sheetContent
    }
    
    public func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isVisible, content: sheetContent)
            .onChange(of: isPresented, initial: true) { old, new in
                isVisible = new != nil
            }
            .onChange(of: isVisible) { old, new in
                guard old != new && !new else {
                    return
                }
                onChange(nil)
            }
    }
}
